import 'package:ctwr_midtown_radio_app/src/error/view.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'dart:io'; // For SocketException
import 'package:flutter/services.dart'; // For PlatformException

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  // for On-Demand Media, we queue up next song in the podcast so use can click "next"
  List<MediaItem> _queue = [];
  int _currentIndex = -1;

  Stream<Duration> get positionStream => _player.positionStream;
  final GlobalKey<NavigatorState> navigatorKey;
  
  // Here we add a bunch of listeners to the _player to broadcast loading, metadata changes to the rest of the app
  AudioPlayerHandler({required this.navigatorKey}) {

    // listen to state changes, buffering, etc. (from playbackEventStream)
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = _player.processingState;
      // get current media item for context
      final currentMediaItem = mediaItem.value;

      playbackState.add(playbackState.value.copyWith(
        controls: _getControls(playing, processingState, currentMediaItem),
        systemActions: _getSystemActions(currentMediaItem),
        processingState: _getAudioServiceProcessingState(processingState),
        playing: playing,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex, // Ensure queueIndex is updated
      ));

      // when current podcast is done, it auto advances to next in the show
      if (processingState == ProcessingState.completed) {
        // only skip to next if it's not a live stream and there's a next item
        if (currentMediaItem?.isLive != true && _currentIndex < _queue.length - 1) {
          Future.microtask(() => skipToNext());
        } else if (currentMediaItem?.isLive != true) {
          // stops at the end of an on-demand queue
          Future.microtask(() => stop());
        } else{
          debugPrint("Error: Live stream should not 'complete'");
        }
      }
    }, 
    onError: (Object e, StackTrace stackTrace) async {
      await stop();

      // update state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: 'Player error: $e',
      ));

      // if no internet, then we show a snackbar, as this is more informative and a little bit nicer for the user.
      // in case of other errors, we navigate to error page, as it is unexpected for other errors to occur. 
      if ((e is PlatformException && e.code == '-1009') ||
        e is SocketException ||
        e.toString().contains('Connection failed')) {

        // show SnackBar for internet issues
        mainScaffoldKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('No internet connection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // navigate to ErrorPage for other errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(
              builder: (_) => ErrorPage(
                error: e.toString(),
                stackTrace: kDebugMode ? stackTrace.toString() : null,
              ),
            ),
          );
        });
      }
    });

    // broadcasts to the rest of the app what position in time the audio is at
    // This happens roughly every second so a progress bar can be displayed
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

  // helper to get state
  AudioProcessingState _getAudioServiceProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
      //default: return AudioProcessingState.error;
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
      // Play is generally available if there's something to play (current item or queue)
      if (mediaItem.value != null || (_queue.isNotEmpty && !isLive)) {
          controls.add(MediaControl.play);
      }
      // Stop is always available if not loading/buffering
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
    Set<MediaAction> actions = {MediaAction.stop}; // Stop is almost always available

    if (_player.playing || mediaItem.value != null || _queue.isNotEmpty) {
        actions.add(MediaAction.playPause);
    }


    if (isLive) {
      // For live, only play/pause and stop
    } else {
      // On-demand can seek
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

  
  // for on demand items - tries to load and play item at given index in queue
  Future<void> _playItemAtIndex(int index, {bool playWhenReady = true}) async {
    if (index < 0 || index >= _queue.length) {
      debugPrint("AudioPlayerHandler: _playItemAtIndex - Index out of bounds: $index");
      await stop(); // Stop if index is invalid
      return;
    }
    _currentIndex = index;
    final newItemToPlay = _queue[index];

    mediaItem.add(newItemToPlay); 

    // set initial loading state for this item
    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,      
      bufferedPosition: Duration.zero, 
      processingState: AudioProcessingState.loading,
      queueIndex: _currentIndex,
      // Controls and system actions will be updated by playbackEventStream and _getControls/_getSystemActions
    ));

    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(newItemToPlay.id)), 
        preload: false,
        initialPosition: Duration.zero, // Always start episodes from the beginning
      );
      if (playWhenReady) {
        _player.play();
      }
    } catch (e, stackTrace) {
      debugPrint("AudioPlayerHandler: Error setting audio source for queue item at index $index ('${newItemToPlay.title}'): $e\n$stackTrace");
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: "Error loading: ${newItemToPlay.title}",
      ));
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    // debugPrint("AudioPlayerHandler: Updating queue with ${queue.length} items.");
    _queue = List.from(queue); // Ensure it's a new list instance
    super.queue.add(_queue); // This updates the queue for audio_service UI (e.g., notification)
    // After updating the queue, re-evaluate controls and system actions.
    // The current mediaItem might still be valid or might need to be reset if it's not in the new queue.
    // If _currentIndex is now invalid for the new queue, it should be reset.
    if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.isNotEmpty ? 0 : -1;
    }
    playbackState.add(playbackState.value.copyWith(
        controls: _getControls(_player.playing, _player.processingState, mediaItem.value),
        systemActions: _getSystemActions(mediaItem.value),
        queueIndex: _currentIndex // Reflect current index
    ));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (mediaItem.value?.isLive == true) return;
    // debugPrint("AudioPlayerHandler: skipToQueueItem called for index $index. Current queue size: ${_queue.length}");
    if (index < 0 || index >= _queue.length) {
        debugPrint("AudioPlayerHandler: skipToQueueItem index $index is out of bounds for queue size ${_queue.length}.");
        return;
    }
    // Update playback state to show loading for the new item
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading));
    await _playItemAtIndex(index, playWhenReady: true);
  }

  @override
  Future<void> skipToNext() async {
    if (mediaItem.value?.isLive == true) return;
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    } else {
      debugPrint("AudioPlayerHandler: Already at the end of the queue.");
      // await stop(); 
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (mediaItem.value?.isLive == true) return;
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    } else {
      debugPrint("AudioPlayerHandler: Already at the beginning of the queue.");
    }
  }
  
  // This method is for setting single items, like a live stream, or a one-off file.
  // It's often an override from BaseAudioHandler if you intend to handle addQueueItem or setItem.
  // For podcast shows, use customSetStream (renamed/repurposed below) or a new dedicated method.
  Future<void> setMediaItem(MediaItem newItem, {bool playWhenReady = false}) async {
    // This will treat the newItem as a queue of one.
    _queue = [newItem];
    _currentIndex = 0; // Will be set by _playItemAtIndex
    super.queue.add(_queue); // Update audio_service queue
    await _playItemAtIndex(0, playWhenReady: playWhenReady); // Play the single item
  }
  
  /// Sets the current playlist to the given list of MediaItems (e.g., all episodes of a podcast show)
  /// and starts playing the item at initialIndex.
  Future<void> setPodcastShowQueue(List<MediaItem> podcastShowEpisodes, int initialIndex, {bool playWhenReady = true}) async {
    if (podcastShowEpisodes.isEmpty) {
      debugPrint("AudioPlayerHandler: setPodcastShowQueue called with empty episode list.");
      await stop(); // Stop playback and clear current state if queue is empty
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
      debugPrint("AudioPlayerHandler: setPodcastShowQueue received invalid initialIndex $initialIndex for queue of ${podcastShowEpisodes.length}. Defaulting to 0.");
      initialIndex = 0; 
    }

    _queue = List.from(podcastShowEpisodes); // Make a mutable copy for internal use
    super.queue.add(List.from(podcastShowEpisodes)); // Broadcast an immutable copy to audio_service

    // _currentIndex will be set correctly by _playItemAtIndex
    // mediaItem will also be updated by _playItemAtIndex
    await _playItemAtIndex(initialIndex, playWhenReady: playWhenReady);
  }

  @override
  Future<void> play() async {
    if (_player.playing) return;

    // debugPrint("AudioPlayerHandler: Play method. CurrentIndex: $_currentIndex, Queue Length: ${_queue.length}, CurrentMediaItem: ${mediaItem.value?.title}");

    if (_currentIndex != -1 && _currentIndex < _queue.length) {
      // If there's a valid current item in the queue that matches the player's perception or needs loading
      final currentQueueItem = _queue[_currentIndex];
      final currentPlayerSourceUri = (_player.audioSource as UriAudioSource?)?.uri.toString();

      if (_player.audioSource != null && currentPlayerSourceUri == currentQueueItem.id) {
        // Source is loaded and matches, just play
        await _player.play();
      } else {
        // Source is not loaded, or doesn't match (e.g., after stop() or queue change), reload and play current item
        // debugPrint("AudioPlayerHandler: Play - Source mismatch or null. Reloading item at index $_currentIndex: ${currentQueueItem.title}");
        await _playItemAtIndex(_currentIndex, playWhenReady: true);
      }
    } else if (_queue.isNotEmpty) {
      // If there's no valid _currentIndex BUT there is a queue (e.g., after stop() or initially)
      // Default to playing the first item in the queue.
      // debugPrint("AudioPlayerHandler: Play - No current index, but queue exists. Playing from start of queue (index 0).");
      await _playItemAtIndex(0, playWhenReady: true);
    } else if (mediaItem.value != null) {
        // No queue, but a single mediaItem might have been set previously (e.g. a live stream via setMediaItem)
        // Attempt to play this single item. setMediaItem will create a temporary queue for it.
        // debugPrint("AudioPlayerHandler: Play - No queue, trying to play current mediaItem.value directly: ${mediaItem.value?.title}");
        await setMediaItem(mediaItem.value!, playWhenReady: true); // This will queue and play it as a single item
    }
     else {
      debugPrint("AudioPlayerHandler: Play called but no media or queue to play effectively.");
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();

    // For on-demand, set current index to -1 to indicate no specific item is "current"
    // but the queue itself remains for potential restart.
    
    // Update playback state to idle, but keep media item and queue if appropriate
    playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        // updatePosition: Duration.zero,
        // queueIndex: _currentIndex,
        controls: _getControls(false, ProcessingState.idle, mediaItem.value),
        systemActions: _getSystemActions(mediaItem.value)
    ));
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

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _player.dispose();
    return super.onTaskRemoved();
  }

  Future<void> customDispose() async {
    await _player.dispose();
  }
}
