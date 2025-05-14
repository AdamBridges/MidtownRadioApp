import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  // for On-Demand Media, we queue up next song in the podcast so use can click "next"
  List<MediaItem> _queue = [];
  int _currentIndex = -1;
  
  // Here we add a bunch of listeners to the _player to broadcast loading, metadata changes to the rest of the app
  AudioPlayerHandler() {

    // listen to state changes, buffering, etc. (from playbackEventStream)
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = _player.processingState;
      // get current media item for context
      final currentMediaItem = mediaItem.value;

      // Inside AudioPlayerHandler constructor, _player.playbackEventStream.listen:
      if (processingState == ProcessingState.completed) {
        debugPrint("AudioPlayerHandler: Item COMPLETED by just_audio: '${currentMediaItem?.title}'");
        debugPrint("  >> At actual player position: ${_player.position}"); // Get current position directly from player
        debugPrint("  >> event.updatePosition was: ${event.updatePosition}");
        debugPrint("  >> MediaItem perceived duration was: ${currentMediaItem?.duration}");
        debugPrint("  >> just_audio _player.duration (last known): ${_player.duration}");
        debugPrint("  >> CurrentIndex: $_currentIndex, Queue Length: ${_queue.length}");
        // ... rest of your logic (Future.microtask(()=> stop()) etc.)
      }


      playbackState.add(playbackState.value.copyWith(
        controls: _getControls(playing, processingState, currentMediaItem),
        systemActions: _getSystemActions(currentMediaItem),
        processingState: _getAudioServiceProcessingState(processingState),
        playing: playing,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
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
          debugPrint("Yeah... this shouldnt happen. theres an error if the live stream 'completes'");
        }
        
      }
    }, 
    
    onError: (Object e, StackTrace stackTrace) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: 'Player error: $e',
      ));
      debugPrint('AUDIO HANDLER ERROR: $e \n$stackTrace');
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
      // if it's a live stream, this listener will still fire from just_audio,
      // but we are choosing not to update the audio_service PlaybackState's position with it.
      // the position for a live stream might still be set to Duration.zero initially by setMediaItem
      // or by the playbackEventStream if it provides a meaningful relative position for live DVR,
      // but this dedicated frequent update is now skipped for live.
    });

    // ICY metadata holds info like the artist, song title and current radio programming in the LIVE broadcast
    // this is encoded in the livestream, so we want to display this to the user so they can see the name of the song on the live radio
    _player.icyMetadataStream.listen((icyMetadata) {
      // Get ICY metadata - in the form 'session - artist - song title'
      // Where 'session' is something like "slow music hour" -- the radio station's programming for that time
      final rawMetaData = icyMetadata?.info?.title;
      // debugPrint("ICY Metadata received: '$rawMetaData'");

      if (rawMetaData == null || rawMetaData.isEmpty) return;

      // Base has all the data of the currently playing audio
      // A lot of the attributes will be null for live music like artist, genre, etc. 
      final base = mediaItem.value;

      // only use ICY if playing and loaded and live
      if (base == null) return;
      if (base.isLive != true) return;

      // parse ICY metadata
      String session = '';
      String artist  = '';
      String title   = '';

      // I noticed sometimes it just is "Airtime - offline" if theres not metadata
      // In this case, I think its nicer to show Midtown Radio KW"
      // this is the default, if not ICY data is given to Airtime in this case, I would rather show "Midtwon Radio KW" than "Airtime - offline"
      if (rawMetaData.trim().toLowerCase() == 'Airtime - offline'){
        session = "radio haha";
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
      if (currentMediaItem != null && duration != null && currentMediaItem.duration != duration) {
        // For live streams, duration might be null or Duration.zero 
        // Only update if it's a meaningful change, especially for on-demand.
        if (currentMediaItem.isLive != true || (duration > Duration.zero)) {
            mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
      }
    });

    // broadcast update to app
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play, MediaControl.stop],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      queueIndex: -1,
    ));

    // mediaItem.listen((item) {
    //   debugPrint("AudioPlayerHandler: mediaItem changed: ${item?.title}, extras: ${item?.extras}");
    // });
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
      if (processingState == ProcessingState.ready ||
          processingState == ProcessingState.completed ||
          processingState == ProcessingState.idle ) {

        if(mediaItem.value != null || (_queue.isNotEmpty && !isLive) ) { 
          // can play if item exists, or if queue exists (for on-demand)
          controls.add(MediaControl.play);
        }
      }
      controls.add(MediaControl.stop);
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
    if (isLive) {
      // no seek or queue navigation for basic live
      return {MediaAction.playPause, MediaAction.stop};
    } else {
      // on-demand content - can go to next , seek forward and back
      Set<MediaAction> actions = {MediaAction.seek};
      if (_queue.isNotEmpty) {
        if (_currentIndex > 0) {
          actions.add(MediaAction.skipToPrevious);
        }
        if (_currentIndex < _queue.length - 1) {
          actions.add(MediaAction.skipToNext);
        }
      }
      return actions;
    }
  }

  // getters for UI
  bool get isLoading => _player.playerState.processingState == ProcessingState.loading || _player.playerState.processingState == ProcessingState.buffering;
  bool get isPlaying => _player.playing;

  
  // for on demand items - tries to load and play item at given index in queue
  Future<void> _playItemAtIndex(int index, {bool playWhenReady = true}) async {
    if (index < 0 || index >= _queue.length) {
      debugPrint("AudioPlayerHandler: _playItemAtIndex - Index out of bounds: $index");
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
      // controls will be updated by the playbackEventStream listener based on player state
    ));

    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(newItemToPlay.id)), 
        preload: false, 
        initialPosition: Duration.zero,
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
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        
      ));
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    debugPrint("AudioPlayerHandler: Updating queue with ${queue.length} items.");
    _queue = queue;
    // update queue and broadcast updates to app
    super.queue.add(_queue);
    playbackState.add(playbackState.value.copyWith(controls: _getControls(_player.playing, _player.processingState, mediaItem.value)));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (mediaItem.value?.isLive == true) return;
    debugPrint("AudioPlayerHandler: skipToQueueItem called for index $index");
    if (index < 0 || index >= _queue.length) return;
    await _playItemAtIndex(index, playWhenReady: true);
  }

  @override
  Future<void> skipToNext() async {
    if (mediaItem.value?.isLive == true) return; // No next for live streams
    // debugPrint("AudioPlayerHandler: skipToNext called. Current index: $_currentIndex, Queue size: ${_queue.length}");
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (mediaItem.value?.isLive == true) return;
    debugPrint("AudioPlayerHandler: skipToPrevious called. Current index: $_currentIndex");
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
  }

  
  Future<void> setMediaItem(MediaItem newItem, {bool playWhenReady = false}) async {
    bool isLive = newItem.isLive == true;
    if (isLive) {
      _queue = [newItem];
      _currentIndex = 0;
      super.queue.add(_queue);
      await _playItemAtIndex(_currentIndex, playWhenReady: playWhenReady);
    } else {
      // For a single on-demand item, behave as before (queue of one)
      _queue = [newItem];
      _currentIndex = 0;
      super.queue.add(_queue);
      await _playItemAtIndex(_currentIndex, playWhenReady: playWhenReady);
    }
  }
  
  Future<void> customSetStream(MediaItem newItem, {bool playWhenReady = true}) async {
    await setMediaItem(newItem, playWhenReady: playWhenReady);
  }

  @override
  Future<void> play() async {
    if (_player.playing) return;

    // Fallback to existing play logic for on-demand, or if live stream wasn't prepared
    debugPrint("AudioPlayerHandler: Standard play call.");
    if (_currentIndex != -1 && _currentIndex < _queue.length) {
      if (_player.audioSource != null) {
        await _player.play();
      } else {
        // If player was stopped and source is null, _playItemAtIndex will set it and play
        await _playItemAtIndex(_currentIndex, playWhenReady: true);
      }
    } else if (mediaItem.value != null) {
      // If no queue context but a single media item was set
      if (_player.audioSource == null || (_player.audioSource?.sequence.first.tag as UriAudioSource?)?.uri.toString() != mediaItem.value!.id) {
          // If current source is not what mediaItem says, or no source, set it and play
          await setMediaItem(mediaItem.value!, playWhenReady: true);
      } else {
          await _player.play(); // Source is already set
      }
    } else {
      debugPrint("AudioPlayerHandler: Play called but no media item to play.");
    }
    
  }

  //   if (_currentIndex != -1 && _currentIndex < _queue.length) {
  //     // if there's a queued item (live or on-demand)
  //     if (_player.audioSource != null) {
  //       await _player.play();
  //     } else {
  //       // if player was stopped and source is null, reload current item
  //       await _playItemAtIndex(_currentIndex, playWhenReady: true);
  //     }
  //   } else if (mediaItem.value != null) {
  //     // if no queue context but a single media item was set (e.g. live stream directly)
  //     await _player.play();
  //   }
  // }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();

    final bool wasLive = mediaItem.value?.isLive == true;
    if (!wasLive) {
        _currentIndex = -1;
    }
    playbackState.add(playbackState.value.copyWith(
        queueIndex: _currentIndex,
        controls: _getControls(false, ProcessingState.idle, mediaItem.value)
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    // seeking should generally be disabled for live streams
    if (mediaItem.value?.isLive == true) return;

    // debugPrint("AudioPlayerHandler: Attempting to seek to $position");
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    try {
      await _player.seek(position);
      //debugPrint("AudioPlayerHandler: Seek to $position completed by player.");
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