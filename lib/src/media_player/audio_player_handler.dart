import 'dart:async';
import 'dart:math';
// import 'package:ctwr_midtown_radio_app/src/error/view.dart';
// import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart'; // For mainScaffoldKey
import 'dart:io'; // For SocketException
import 'package:flutter/services.dart'; // For PlatformException
import 'package:connectivity_plus/connectivity_plus.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  List<MediaItem> _queue = [];
  int _currentIndex = -1;
  bool _isProcessingSkip = false;

  // variables to recover stream automatically if the connection cuts out
  // * NOTE: this does NOT work reliably SPECIFICALLY on IOS SIMULATORS
  // on real devices it works fine. be aware of this if testing
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _shouldAutoRecover = false;
  int _retryAttempt = 0;
  DateTime? _lastRetryTime;
  MediaItem? _currentLiveStreamToRecover;

  // debounce for connectivity changes to avoid rapid triggers
  Timer? _connectivityDebounceTimer;

  Stream<Duration> get positionStream => _player.positionStream;
  final GlobalKey<NavigatorState> navigatorKey;

  AudioPlayerHandler({required this.navigatorKey}) {
    // check for changes in internet connectivity -- if internet cuts out and comes back, we attempt reconnect
    _initConnectivityMonitoring();

    // update processing state
    // if a livestream reports "completed" then we attepmt to reset and recover the audio since this only happens when something goes wrong.
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = _player.processingState;
      final currentMediaItemFromPlayer = mediaItem.value;

      //debugPrint("AudioPlayerHandler State: $processingState, Playing: $playing, Current MediaItem ID: ${currentMediaItemFromPlayer?.id}, AutoRecover: $_shouldAutoRecover, RetryAttempt: $_retryAttempt");

      // broadcast changed state
      playbackState.add(playbackState.value.copyWith(
        controls: _getControls(playing, processingState, currentMediaItemFromPlayer),
        systemActions: _getSystemActions(currentMediaItemFromPlayer),
        processingState: _getAudioServiceProcessingState(processingState),
        playing: playing,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));

      // If player becomes ready and is playing, reset recovery state
      if (processingState == ProcessingState.ready && playing) {
        if (_shouldAutoRecover) {
          debugPrint("AudioPlayerHandler: Stream successfully started/recovered and is playing.");
          _retryAttempt = 0;
          _shouldAutoRecover = false;
          _lastRetryTime = null;
          _currentLiveStreamToRecover = null;
        }
      }

      if (processingState == ProcessingState.completed) {
        // sometimes theres an issue caused by the backend 
        // where the audio sees the full duration, ie 55 mins, and sees the player position is like 0:00
        // and it still marks it "complete"
        // the following is to shield from that and notify users if that happens.
        // we want this snackbar to show when this happens, but not on a normal completion.
        // from testing, a normal completion can be off by a few milliseconds, and an error will be off by the whole length of the show
        if (currentMediaItemFromPlayer?.duration != null &&
            (_player.position - currentMediaItemFromPlayer!.duration!).abs() >= Duration(seconds: 5)) {

          Future.microtask(() => stop());
          _showErrorSnackbar('Sorry, can\'t play this audio.');
        } else {
          if (currentMediaItemFromPlayer?.isLive != true && _currentIndex < _queue.length - 1) {
            Future.microtask(() => skipToNext());
          } else if (currentMediaItemFromPlayer?.isLive != true) {
            Future.microtask(() => stop()); // End of on-demand queue

          } else if (currentMediaItemFromPlayer?.isLive == true) {
            debugPrint("AudioPlayerHandler: Live stream reported 'completed' unexpectedly.");

            // this is an abnormal state for a live stream.
            // stop the player and flag for recovery.
            if (_currentLiveStreamToRecover == null && mediaItem.value != null) {
                 _currentLiveStreamToRecover = mediaItem.value;
            }
            Future.microtask(() async {
                await _player.stop();
                playbackState.add(playbackState.value.copyWith(
                    processingState: AudioProcessingState.idle,
                    playing: false));
            });
            _shouldAutoRecover = true;
            _retryAttempt = 0;
            _lastRetryTime = null;
            _showInfoSnackbar('Live stream interrupted. Attempting to reconnect...');
            _handleReconnection();
          }
        }
      }
    }, 
    onError: (Object e, StackTrace stackTrace) async {
      debugPrint("AudioPlayerHandler: onError: $e, StackTrace: $stackTrace");
      // if error is caused by lack of connectivity, then we also try to recover
      if (_isNetworkError(e)) {
        debugPrint("AudioPlayerHandler: Network error detected.");
        if (mediaItem.value?.isLive == true) { // Only auto-recover live streams
          _currentLiveStreamToRecover = mediaItem.value; // Store what was trying to play
          _shouldAutoRecover = true;
          _retryAttempt = 0;
          _lastRetryTime = null;
          _showErrorSnackbar('Connection issue. Attempting to reconnect stream...');
          // Stop the player to ensure it's in a clean state for reconnect
          await _player.stop();
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
            errorMessage: 'Network error. Trying to reconnect...',
          ));
          // _handleReconnection(); // Let connectivity listener or timed retry handle it
        } else {
          // For on-demand content with network error
          await stop();
          _showErrorSnackbar('Network error. Please check your connection.');
           playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.error, playing: false, errorMessage: 'Network error: $e'));
        }
      } else { 
        // Non-network related error
        debugPrint("AudioPlayerHandler: Non-network error. Stopping player.");
        await stop();
        _showErrorSnackbar('An unexpected audio error occurred.');
        playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error, playing: false, errorMessage: 'Player error: $e'));
      }
    });

    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play, MediaControl.stop],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      queueIndex: -1,
    ));

    // update position of stream for rest of the app
    _player.positionStream.listen((position) {
      final currentItem = mediaItem.value;
      final bool isLive = currentItem?.isLive == true;

      // only update and broadcast position for on-demand content.
      // for live streams, the UI will typically hide the seek bar and time progression
      if (!isLive) {
        // debugPrint("AudioPlayerHandler: PositionStream (On-Demand): pos=$position");
        playbackState.add(playbackState.value.copyWith(
          updatePosition: position,
        ));
      }
    });

    // ICY metadata holds info like the artist, song title and current radio programming in the LIVE broadcast
    // this is encoded in the livestream, so we want to display this to the user so they can see the name of the song on the live radio
    _player.icyMetadataStream.listen((icyMetadata) {
      // debugPrint("${icyMetadata?.info?.title}");
      // Get ICY metadata - in the form 'session - artist - song title'
      // Where 'session' is something like "slow music hour" -- the radio station's programming for that time
      final rawMetaData = icyMetadata?.info?.title;
      // debugPrint("ICY Metadata received: '$rawMetaData'");

      if (rawMetaData == null || rawMetaData.isEmpty) return;

      // Base has all the data of the currently playing audio
      // A lot of the attributes will be null for live music like artist, genre, etc. 
      final base = mediaItem.value;
      if (base == null || base.isLive != true) return;

      // parse ICY metadata
      String session = '';
      String artist  = '';
      String title   = '';

      // I noticed sometimes it just is "Airtime - offline" if theres not metadata
      // In this case, I think its nicer to show Midtown Radio KW"
      // this is the default, if not ICY data is given to Airtime in this case, I would rather show "Midtwon Radio KW" than "Airtime - offline"
      if (rawMetaData.contains('Airtime - offline')){
        session = "";
        artist = "";
        title = "Midtown Radio KW";

      // If we DO actually have data that is not the defualt: 
      } else {
        final parts = rawMetaData.split(' - ');
        // We typically always have 3 parts 'session - artist - song, but this can handle 2 also
        if (parts.length == 3) {
          session = parts[0].trim();
          artist = parts[1].trim();
          title = parts[2].trim();
        } else if (parts.length == 2) {
          artist = parts[0].trim();
          title = parts[1].trim();
        } else {
          title = rawMetaData.trim(); // Fallback if format is unexpected
        }
      }
      
      // only rebuild if something changed
      if (title != base.title || artist != base.artist || session != base.genre) {
        // update with new Metadata - we update the fields and also provider raw ICY in "extras"
        final updated = base.copyWith(
          title:  title,
          artist: artist,
          genre:  session,
          extras: {
            ...?base.extras,
            'icyRaw': rawMetaData,
            'icySession': session,
          },
        );

        // broadcast updated ICY to rest of app
        mediaItem.add(updated);
        // debugPrint("Updated Live MediaItem: $updated");
      }
    });

    // updates the duration of the currently playing audio, for example when a song is changed
    _player.durationStream.listen((duration) {
       final currentMediaItem = mediaItem.value;
      // debugPrint("AudioPlayerHandler: DurationStream reported by just_audio for '${currentMediaItem?.title}': $duration");
        // For live streams, duration might be null or Duration.zero 
        // Only update if it's a meaningful change, especially for on-demand.
      if (currentMediaItem != null && duration != null && currentMediaItem.duration != duration) {
        if (currentMediaItem.isLive != true || (duration > Duration.zero)) {
            mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
      }
    });

    // broadcast update to app
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play, MediaControl.stop], // Initial minimal controls
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      queueIndex: -1, // Initial queue index
    ));
  
  }

  // listens to changes in connectivity to initiate recovery if needed
  void _initConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
       _connectivityDebounceTimer?.cancel();
      _connectivityDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        bool isConnected = !results.contains(ConnectivityResult.none);
        debugPrint("AudioPlayerHandler: Debounced Connectivity changed. Is connected: $isConnected. Results: $results. ShouldAutoRecover: $_shouldAutoRecover");

        if (isConnected) {
          // if connecting after being disconnected, reconnect
          if (_shouldAutoRecover && _currentLiveStreamToRecover != null) {
            debugPrint("AudioPlayerHandler: Connection restored and auto-recovery is pending. Triggering reconnection.");
            _handleReconnection();
          } else if (_shouldAutoRecover && _currentLiveStreamToRecover == null && mediaItem.value?.isLive == true) {
            // This might happen if error occurred before live stream was stored
            _currentLiveStreamToRecover = mediaItem.value;
            debugPrint("AudioPlayerHandler: Connection restored, auto-recovery pending, live item was not stored, trying current mediaItem.");
            if(_currentLiveStreamToRecover != null) _handleReconnection();
          }
        } else {
          debugPrint("AudioPlayerHandler: Connection lost (ConnectivityResult.none).");
          // If playing a live stream, player will likely error out. onError will set recovery flags.
          if (_player.playing && mediaItem.value?.isLive == true) {
            _currentLiveStreamToRecover = mediaItem.value; // Proactively store
            // Don't set _shouldAutoRecover here, let onError do it to avoid conflicts
            _showInfoSnackbar("Connection lost. Player will attempt to reconnect if connection returns.");
          }
        }
      });
    });
  }

  // reconnects stream. call when internet is back
  Future<void> _handleReconnection() async {
    if (!_shouldAutoRecover || _currentLiveStreamToRecover == null) {
      debugPrint("_handleReconnection: Aborting. AutoRecover: $_shouldAutoRecover, LiveStreamToRecover: ${_currentLiveStreamToRecover?.id}");
      return;
    }

    // If player is somehow already playing the correct stream, abort.
    if (_player.playing && 
    _player.processingState == ProcessingState.ready &&
    _player.audioSource != null && 
    (_player.audioSource as UriAudioSource).uri.toString().startsWith(_currentLiveStreamToRecover!.id.split("?")[0])) {
      
      debugPrint("_handleReconnection: Player is already playing the target stream properly. Aborting recovery.");
      _shouldAutoRecover = false;
      _retryAttempt = 0;
      _lastRetryTime = null;
      _currentLiveStreamToRecover = null;
      return;
    }

    // exponential time delay - at first we retry frequently, and we retry less and less often 
    // ie after 1, then 2, then 4, 8, 16, 32 seconds, up to a minute maximum
    final backoffDelay = Duration(seconds: min(60, pow(2, _retryAttempt).toInt()));
    final now = DateTime.now();

    if (_lastRetryTime != null && now.difference(_lastRetryTime!) < backoffDelay) {
      debugPrint("_handleReconnection: Throttled by backoff ($backoffDelay). Will try again after ${backoffDelay - now.difference(_lastRetryTime!)}.");
      // Schedule the next check if not relying on connectivity events alone
      // This can be tricky; for now, let connectivity events or manual play be the trigger.
      return;
    }

    _showInfoSnackbar('Attempting to reconnect stream (attempt ${_retryAttempt + 1})...');
    debugPrint('AudioPlayerHandler: Attempting audio recovery for live stream "${_currentLiveStreamToRecover!.id}" (attempt $_retryAttempt). Delay: $backoffDelay');
    
    _lastRetryTime = now; // Set time before the attempt

    // Update UI to show loading
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      playing: false,
      errorMessage: null, // Clear previous errors
    ));
    // Ensure audio_service knows what we're trying to play
    if (mediaItem.value?.id != _currentLiveStreamToRecover!.id) {
        mediaItem.add(_currentLiveStreamToRecover); // Update mediaItem stream for audio_service
    }


    try {
      // Stop the player completely before setting a new source to ensure a clean state.
      await _player.stop();
      // Brief delay can sometimes help platforms settle.
      await Future.delayed(const Duration(milliseconds: 250));

      debugPrint("AudioPlayerHandler: Re-initiating live stream via setMediaItem: ${_currentLiveStreamToRecover!.id}");
      // Use setMediaItem to ensure all internal states and audio_service are correctly managed.
      // setMediaItem will call _playItemAtIndex, which handles cache-busting.
      await setMediaItem(_currentLiveStreamToRecover!, playWhenReady: true);
      
      _retryAttempt++; // Increment for the next potential backoff. Reset to 0 on confirmed play by playbackEventStream.
      // Note: _shouldAutoRecover remains true. It's set to false by playbackEventStream when play is successful.
      
    } catch (e) {
      debugPrint('AudioPlayerHandler: Recovery attempt failed: $e');
      _retryAttempt++;
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: "Reconnect failed (attempt $_retryAttempt): $e",
      ));
      if (_retryAttempt > 5) { // Max retries for this recovery cycle
        _showErrorSnackbar("Failed to reconnect after multiple attempts. Please try playing again manually.");
        debugPrint("AudioPlayerHandler: Max recovery attempts reached. Stopping auto-recovery for this cycle.");
        _shouldAutoRecover = false;
        _retryAttempt = 0;
        _currentLiveStreamToRecover = null; // Give up on this specific item for auto-recovery
      } else {
        // The backoff logic at the start of this function will handle the delay for the next attempt,
        // which might be triggered by another connectivity event or a manual play.
         _showErrorSnackbar("Reconnect attempt failed. Will try again shortly.");
      }
    }
  }

  // checks that would indicate the error is related to a faulty network connection
  bool _isNetworkError(Object error) {
    if (error is PlayerException) {
        return error.code == -1004 || // Example Android MEDIA_ERROR_IO
               (error.message?.toLowerCase().contains("source error") ?? false) ||
               (error.message?.toLowerCase().contains("network") ?? false) ||
               (error.message?.toLowerCase().contains("connect") ?? false);
    }
    return error is SocketException ||
        error is TimeoutException ||
        (error is PlatformException && (error.code == 'network_error' || error.code == '-1009' || error.message?.toLowerCase().contains("network connection") == true)) ||
        error.toString().toLowerCase().contains('connection failed') ||
        error.toString().toLowerCase().contains('host unreachable') ||
        error.toString().toLowerCase().contains('failed host lookup');
  }

  void _showErrorSnackbar(String message) {
    mainScaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  void _showInfoSnackbar(String message) {
     mainScaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // set the item to play
  Future<void> setMediaItem(MediaItem newItem, {bool playWhenReady = false}) async {
    debugPrint("AudioPlayerHandler: setMediaItem called for '${newItem.id}' (Live: ${newItem.isLive})");
    if (newItem.isLive == true) {
      // If this setMediaItem call is not part of a recovery for the *same* stream,
      // or if there's no recovery in progress, then this is a new live stream selection.
      if (_currentLiveStreamToRecover?.id != newItem.id || !_shouldAutoRecover) {
        _currentLiveStreamToRecover = newItem; // Store/update the primary live stream item
        _shouldAutoRecover = false; // New item selected, reset recovery for any old one
        _retryAttempt = 0;
        _lastRetryTime = null;
        debugPrint("AudioPlayerHandler: New live stream selected or recovery reset. Stored: ${newItem.id}");
      }
    } else {
      // If an on-demand item is selected, clear live stream recovery efforts.
      if (_currentLiveStreamToRecover != null) {
        debugPrint("AudioPlayerHandler: On-demand item selected, clearing live stream recovery state.");
      }
      _currentLiveStreamToRecover = null;
      _shouldAutoRecover = false;
      _retryAttempt = 0;
      _lastRetryTime = null;
    }

    _queue = [newItem];
    _currentIndex = 0;
    super.queue.add(_queue); // Update audio_service queue
    await _playItemAtIndex(0, playWhenReady: playWhenReady); // Play the single item
  }
  
  Future<void> _playItemAtIndex(int index, {bool playWhenReady = true}) async {
    if (index < 0 || index >= _queue.length) {
      await stop();
      return;
    }
    _currentIndex = index;
    final newItemToPlay = _queue[index];

    mediaItem.add(newItemToPlay); // Broadcast this item to audio_service

    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      processingState: AudioProcessingState.loading, // Set to loading
      queueIndex: _currentIndex,
      playing: false, // Explicitly set playing to false when loading a new item
      errorMessage: null, // Clear any previous error message
    ));

    try {
      // await _player.stop();
      String urlToPlay = newItemToPlay.id;
      Map<String, String>? headers;

      if (newItemToPlay.isLive == true) {
        // Basic cache busting by removing old query params and adding a new timestamp
        var uri = Uri.parse(newItemToPlay.id);
        uri = uri.replace(queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()});
        urlToPlay = uri.toString();
        debugPrint("AudioPlayerHandler: Playing live stream with cache-busted URL: $urlToPlay");
        // Some streams might require specific headers, e.g., to prevent caching by intermediaries
        // headers = {'Cache-Control': 'no-cache, no-store', 'Pragma': 'no-cache'};
      }
      
      // For live streams, just_audio often handles HLS/DASH specifics well.
      // Using default AudioLoadConfiguration.
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(urlToPlay), headers: headers),
        preload: newItemToPlay.isLive != true, // More aggressive preload for on-demand
        initialPosition: Duration.zero, // Live streams start from current, on-demand from beginning
      );

      if (playWhenReady) {
        await _player.play();
      }
    } catch (e, stackTrace) {
      debugPrint("AudioPlayerHandler: Error in _playItemAtIndex for '${newItemToPlay.id}': $e\n$stackTrace");
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: "Error loading: ${newItemToPlay.title}. Details: $e",
      ));
      // If this error occurs during a recovery attempt, let onError handler manage recovery flags.
    }
  }

  @override
  Future<void> play() async {
    // If play is manually called, we assume user intent supersedes auto-recovery for a moment.
    // If it's a live stream and was pending recovery, this manual play *is* the recovery attempt.
    if (_shouldAutoRecover && _currentLiveStreamToRecover != null && mediaItem.value?.id == _currentLiveStreamToRecover!.id) {
        debugPrint("AudioPlayerHandler: Manual play call is effectively a recovery attempt for pending live stream.");
        // Allow _handleReconnection logic to proceed if it's triggered, or this play itself succeeds.
        // Resetting _lastRetryTime allows the backoff in _handleReconnection to not overly throttle this.
        _lastRetryTime = null; 
        // Call _handleReconnection which will use setMediaItem
        _handleReconnection(); // This will use the stored _currentLiveStreamToRecover
        return; // _handleReconnection will take over.
    }


    if (_player.playing) return;

    if (_currentIndex != -1 && _currentIndex < _queue.length) {
      final currentQueueItem = _queue[_currentIndex];
      final currentPlayerSourceUri = (_player.audioSource as UriAudioSource?)?.uri.toString().split("?")[0]; // Compare without query params
      final queueItemUri = currentQueueItem.id.split("?")[0];

      if (_player.audioSource != null && currentPlayerSourceUri == queueItemUri && _player.processingState != ProcessingState.idle) {
         debugPrint("AudioPlayerHandler: Play - Source matches and not idle, calling _player.play()");
        await _player.play();
      } else {
        debugPrint("AudioPlayerHandler: Play - Source mismatch, null, or idle. Reloading item at index $_currentIndex: ${currentQueueItem.title}");
        await _playItemAtIndex(_currentIndex, playWhenReady: true);
      }
    } else if (_queue.isNotEmpty) {
      debugPrint("AudioPlayerHandler: Play - No current index, but queue exists. Playing from start (index 0).");
      await _playItemAtIndex(0, playWhenReady: true);
    } else if (mediaItem.value != null) {
      debugPrint("AudioPlayerHandler: Play - No queue, trying to play current mediaItem.value: ${mediaItem.value?.title}");
      await setMediaItem(mediaItem.value!, playWhenReady: true);
    } else {
      debugPrint("AudioPlayerHandler: Play called but no media or queue to play.");
    }
  }


  @override
  Future<void> stop() async {
    debugPrint("AudioPlayerHandler: stop() called. Clearing recovery flags.");
    await _player.stop();
    _shouldAutoRecover = false;
    _retryAttempt = 0;
    _lastRetryTime = null;
    // Don't clear _currentLiveStreamToRecover here, as user might hit play again for the same live stream.
    // Let setMediaItem manage it.

    playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: _getControls(false, ProcessingState.idle, mediaItem.value),
        systemActions: _getSystemActions(mediaItem.value)
    ));
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _player.dispose();
    _connectivityDebounceTimer?.cancel();
    await _connectivitySubscription?.cancel();
    debugPrint("AudioPlayerHandler: Disposed and connectivity monitoring stopped.");
    return super.onTaskRemoved();
  }
  
// helper to get state
  AudioProcessingState _getAudioServiceProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  // returns allowed controls (play, pause, skip, previous)
  List<MediaControl> _getControls(bool isPlaying, ProcessingState processingState, MediaItem? currentItem) {
    List<MediaControl> controls = [];
    final bool isLive = currentItem?.isLive == true;

    if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
      controls.add(MediaControl.stop);
    } else if (isPlaying) {
      controls.add(MediaControl.pause);
      controls.add(MediaControl.stop);
    } else {
      if (mediaItem.value != null || (_queue.isNotEmpty && !isLive)) {
          controls.add(MediaControl.play);
      }
       if (processingState != ProcessingState.idle || mediaItem.value != null) {
            controls.add(MediaControl.stop);
       }
    }
    // Add queue navigation controls ONLY for on-demand content with a queue
    if (!isLive && _queue.isNotEmpty) {
      if (_currentIndex > 0) {
        controls.add(MediaControl.skipToPrevious);
      }
      if (_currentIndex < _queue.length - 1) {
        controls.add(MediaControl.skipToNext);
      }
    }
    return controls;
  }
  // helper to determine system actions based on media type

  Set<MediaAction> _getSystemActions(MediaItem? currentItem) {
    final bool isLive = currentItem?.isLive == true;
    Set<MediaAction> actions = {MediaAction.stop}; 

    if (_player.playing || mediaItem.value != null || _queue.isNotEmpty) {
        actions.add(MediaAction.playPause);
    }


    if (isLive) {
      // Live: Play/Pause, Stop
    } else {
      // On-demand: Seek, Skip
      actions.add(MediaAction.seek);
      if (_queue.isNotEmpty) {
        if (_currentIndex > 0) {
          actions.add(MediaAction.skipToPrevious);
        }
        if (_currentIndex < _queue.length - 1) {
          actions.add(MediaAction.skipToNext);
        }
      }
    }
    return actions;
  }
  // getters for UI
  bool get isLoading => _player.playerState.processingState == ProcessingState.loading || _player.playerState.processingState == ProcessingState.buffering;
  bool get isPlaying => _player.playing;


  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queue = List.from(queue); 
    super.queue.add(_queue); 
    if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.isNotEmpty ? 0 : -1;
    }
    playbackState.add(playbackState.value.copyWith(
        controls: _getControls(_player.playing, _player.processingState, mediaItem.value),
        systemActions: _getSystemActions(mediaItem.value),
        queueIndex: _currentIndex 
    ));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (mediaItem.value?.isLive == true) return;
    if (index < 0 || index >= _queue.length) {
        return;
    }
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading));
    await _playItemAtIndex(index, playWhenReady: true);
  }

  @override
  Future<void> skipToNext() async {
    //ebugPrint("tried to skip: ${_isProcessingSkip}");
    if (mediaItem.value?.isLive == true || _isProcessingSkip) return;
    _isProcessingSkip = true;

    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
    //debugPrint("ran");
    _isProcessingSkip = false;
  }

  @override
  Future<void> skipToPrevious() async {
    if (mediaItem.value?.isLive == true || _isProcessingSkip) return;
    _isProcessingSkip = true;

    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
    _isProcessingSkip = false;

  }
  
  Future<void> setPodcastShowQueue(List<MediaItem> podcastShowEpisodes, int initialIndex, {bool playWhenReady = true}) async {
    if (podcastShowEpisodes.isEmpty) {
      await stop(); 
      mediaItem.add(null);
      _queue = [];
      super.queue.add(_queue);
      _currentIndex = -1;
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        queueIndex: _currentIndex,
        controls: _getControls(false, ProcessingState.idle, null),
        systemActions: _getSystemActions(null),
      ));
      return;
    }

    if (initialIndex < 0 || initialIndex >= podcastShowEpisodes.length) {
      initialIndex = 0; 
    }

    _queue = List.from(podcastShowEpisodes); 
    super.queue.add(List.from(podcastShowEpisodes)); 
    await _playItemAtIndex(initialIndex, playWhenReady: playWhenReady);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (mediaItem.value?.isLive == true) return;
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint("AudioPlayerHandler: Error during seek: $e");
    }
  }
}
