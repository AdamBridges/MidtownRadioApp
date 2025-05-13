import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  List<MediaItem> _queue = [];
  int _currentIndex = -1;
  MediaItem? _liveStreamBaseMediaItem; // Stores the original details of the live stream

  AudioPlayerHandler() {


    // --- Listener 1: For state changes, buffering, etc. (from playbackEventStream) ---
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = _player.processingState;
      final currentMediaItem = mediaItem.value; // Get current media item for context

      playbackState.add(playbackState.value.copyWith(
        controls: _getControls(playing, processingState, currentMediaItem), // Pass currentMediaItem
        systemActions: _getSystemActions(currentMediaItem), // System actions based on media type
        processingState: _getAudioServiceProcessingState(processingState),
        playing: playing,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));

      if (processingState == ProcessingState.completed) {
        // Only skip to next if it's not a live stream and there's a next item
        if (currentMediaItem?.extras?['isLiveStream'] != true && _currentIndex < _queue.length - 1) {
          skipToNext();
        } else if (currentMediaItem?.extras?['isLiveStream'] != true) {
          // Optional: At the end of an on-demand queue
          stop();
        }
        // For live streams, completed state usually means stream ended or error
      }
    }, onError: (Object e, StackTrace stackTrace) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: 'Player error: $e',
      ));
      debugPrint('AUDIO HANDLER ERROR: $e \n$stackTrace');
    });

    // --- Listener 2: SPECIFICALLY for live position updates (from positionStream) ---
    _player.positionStream.listen((position) {
      final currentItem = mediaItem.value;
      // Only update position if it's not a live stream or if it's a live stream with DVR capabilities
      // For basic live streams, position might always be zero or relative, so UI might hide it.
      // For now, we always update it, UI will decide to show/hide.
      if (currentItem?.extras?['isLiveStream'] == true && (currentItem?.duration == null || currentItem?.duration == Duration.zero)) {
        // For live streams without a known duration (typical case), position is often relative or less meaningful.
        // We might still want to broadcast it if the stream supports seeking within a live window.
        // For now, let it update. The UI can choose to hide the seek bar for live.
      }
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // ICY metadata holds info like the artist, song title and current radio programming
    // this is encoded in the livestream, so we want to display this to the user so they can see the name of the song on the live radio
    _player.icyMetadataStream.listen((icyMetadata) {
      // Get ICY metadata - in the form 'session - artist - song title'
      // Where 'session' is something like "slow music hour" -- the radio station's programming for that time
      final rawMetaData = icyMetadata?.info?.title;
      debugPrint("ICY Metadata received: '$rawMetaData'");

      if (rawMetaData == null || rawMetaData.isEmpty) return;

      // Base has all the data of the currently playing audio
      // A lot of the attributes will be null for live music like artist, genre, etc. 
      final base = mediaItem.value;

      // Nothing playing/loaded
      if (base == null) return;

      // Only using ICY for live music
      if (base.isLive != true) return;

      // parse ICY metadata
      var session = '';
      var artist  = '';
      var title   = '';

      final parts = rawMetaData.split(' - ');

      // We typically always have 3
      if (parts.length == 3) {
        session = parts[0].trim();
        artist  = parts[1].trim();
        title   = parts[2].trim();
      } else if (parts.length == 2) {
        artist  = parts[0].trim();
        title   = parts[1].trim();
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
        _liveStreamBaseMediaItem = updated;
        debugPrint("Updated Live MediaItem: $updated");
      }
    });

    _player.durationStream.listen((duration) {
       final currentMediaItem = mediaItem.value;
      if (currentMediaItem != null && duration != null && currentMediaItem.duration != duration) {
        // For live streams, duration might be null or Duration.zero or sometimes a large value for DVR window
        // Only update if it's a meaningful change, especially for on-demand.
        if (currentMediaItem.extras?['isLiveStream'] != true || (duration > Duration.zero)) {
            mediaItem.add(currentMediaItem.copyWith(duration: duration));
        }
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

    mediaItem.listen((item) {
      debugPrint("AudioPlayerHandler: mediaItem changed: ${item?.title}, extras: ${item?.extras}");
    });

  }

  AudioProcessingState _getAudioServiceProcessingState(ProcessingState processingState) {
    // ... (same as before) ...
    switch (processingState) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
      default: return AudioProcessingState.error;
    }
  }

  List<MediaControl> _getControls(bool isPlaying, ProcessingState processingState, MediaItem? currentItem) {
    List<MediaControl> controls = [];
    final bool isLive = currentItem?.extras?['isLiveStream'] == true;

    if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
      controls.add(MediaControl.stop);
    } else if (isPlaying) {
      controls.add(MediaControl.pause);
      controls.add(MediaControl.stop);
    } else {
      if (processingState == ProcessingState.ready ||
          processingState == ProcessingState.completed ||
          processingState == ProcessingState.idle ) {
        if(mediaItem.value != null || (_queue.isNotEmpty && !isLive) ) { // Can play if item exists, or if queue exists (for on-demand)
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

  // Helper to determine system actions based on media type
  Set<MediaAction> _getSystemActions(MediaItem? currentItem) {
    final bool isLive = currentItem?.extras?['isLiveStream'] == true;
    if (isLive) {
      // Live streams typically don't support seek, skipToNext, skipToPrevious in the same way
      // Some live streams might have DVR (seek within a window), but we'll keep it simple here.
      return {}; // No seek or queue navigation for basic live
    } else {
      // On-demand content
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

  bool get isLoading => _player.playerState.processingState == ProcessingState.loading || _player.playerState.processingState == ProcessingState.buffering;
  bool get isPlaying => _player.playing;
  String get isCurrentlyPlaying => mediaItem.value?.extras?['icySession'] ?? mediaItem.value?.title ?? "Nothing is loaded...";


  Future<void> _playItemAtIndex(int index, {bool playWhenReady = true}) async {
    if (index < 0 || index >= _queue.length) {
      debugPrint("AudioPlayerHandler: _playItemAtIndex - Index out of bounds: $index");
      return;
    }
    _currentIndex = index;
    final newItemToPlay = _queue[index];
    
    // For live streams, _liveStreamBaseMediaItem should be set when the stream starts.
    // If this item being played is marked as live, ensure _liveStreamBaseMediaItem is this item.
    if (newItemToPlay.extras?['isLiveStream'] == true) {
        _liveStreamBaseMediaItem = newItemToPlay;
    } else {
        // If playing an on-demand item, clear _liveStreamBaseMediaItem so ICY updates don't affect it.
        _liveStreamBaseMediaItem = null;
    }

    mediaItem.add(newItemToPlay); 

    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,      
      bufferedPosition: Duration.zero, 
      processingState: AudioProcessingState.loading,
      queueIndex: _currentIndex,          
    ));

    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(newItemToPlay.id)), preload: false);
      if (playWhenReady) {
        _player.play();
      }
    } catch (e) {
      debugPrint("AudioPlayerHandler: Error setting audio source for queue item at index $index: $e");
      playbackState.add(playbackState.value.copyWith( /* ... error state ... */ ));
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    debugPrint("AudioPlayerHandler: Updating queue with ${newQueue.length} items.");
    _queue = newQueue;
    super.queue.add(_queue); // Inform audio_service clients
    _liveStreamBaseMediaItem = null; // Assume a queue update means we are in on-demand mode for now
                                   // This might need refinement if you mix live items in queues.
    playbackState.add(playbackState.value.copyWith(controls: _getControls(_player.playing, _player.processingState, mediaItem.value)));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (mediaItem.value?.extras?['isLiveStream'] == true) return; // Don't skip in queue for live streams
    debugPrint("AudioPlayerHandler: skipToQueueItem called for index $index");
    if (index < 0 || index >= _queue.length) return;
    await _playItemAtIndex(index, playWhenReady: true);
  }

  @override
  Future<void> skipToNext() async {
    if (mediaItem.value?.extras?['isLiveStream'] == true) return; // No next for live streams
    debugPrint("AudioPlayerHandler: skipToNext called. Current index: $_currentIndex, Queue size: ${_queue.length}");
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (mediaItem.value?.extras?['isLiveStream'] == true) return; // No previous for live streams
    debugPrint("AudioPlayerHandler: skipToPrevious called. Current index: $_currentIndex");
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
  }

  @override
  Future<void> setMediaItem(MediaItem newItem, {bool playWhenReady = false}) async {
    bool isLive = newItem.extras?['isLiveStream'] == true;
    if (isLive) {
      _liveStreamBaseMediaItem = newItem; // Store base details for live stream
      _queue = [newItem]; // Live stream is a queue of one
      _currentIndex = 0;
      super.queue.add(_queue); // Update audio_service's broadcasted queue
      await _playItemAtIndex(_currentIndex, playWhenReady: playWhenReady);
    } else {
      // For a single on-demand item, behave as before (queue of one)
      _liveStreamBaseMediaItem = null;
      _queue = [newItem];
      _currentIndex = 0;
      super.queue.add(_queue);
      await _playItemAtIndex(_currentIndex, playWhenReady: playWhenReady);
    }
  }
  
  Future<void> customSetStream(MediaItem newItem) async {
    // If this is for on-demand episode lists, it should ideally call updateQueue and skipToQueueItem.
    // If it's for a single item (live or on-demand) with auto-play:
    await setMediaItem(newItem, playWhenReady: true);
  }

  @override
  Future<void> play() async {
    // Handle play command, especially if coming from notification or headset
    if (!_player.playing) {
      if (_currentIndex != -1 && _currentIndex < _queue.length) {
        // If there's a cued item (live or on-demand)
        if (_player.audioSource != null) {
          await _player.play();
        } else {
          // If player was stopped and source is null, reload current item
          await _playItemAtIndex(_currentIndex, playWhenReady: true);
        }
      } else if (mediaItem.value != null) {
        // If no queue context but a single media item was set (e.g. live stream directly)
         await _player.play();
      }
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    // For live streams, stopping might clear _liveStreamBaseMediaItem if you want fresh ICY info on next play.
    // For now, we just reset index.
    final bool wasLive = mediaItem.value?.extras?['isLiveStream'] == true;
    if (!wasLive) { // Only reset current index for on-demand queues, live stream is always index 0 of its "queue"
        _currentIndex = -1;
    }
    // The playbackEventStream listener will broadcast the idle state.
    playbackState.add(playbackState.value.copyWith(
        queueIndex: _currentIndex,
        controls: _getControls(false, ProcessingState.idle, mediaItem.value) // Pass mediaItem for context
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    // Seeking should generally be disabled for live streams without DVR
    if (mediaItem.value?.extras?['isLiveStream'] == true) {
        // For some live streams (with DVR), seeking might be allowed within a window.
        // For basic live streams, often not. For now, we allow it if systemActions permit.
        // The UI should hide the seek bar for non-seekable live streams.
    }
    debugPrint("AudioPlayerHandler: Attempting to seek to $position");
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    try {
      await _player.seek(position);
      debugPrint("AudioPlayerHandler: Seek to $position completed by player.");
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