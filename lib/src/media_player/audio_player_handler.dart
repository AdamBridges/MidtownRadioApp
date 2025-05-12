import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayerHandler() {
    // --- Listener 1: For state changes, buffering, etc. (from playbackEventStream) ---
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = _player.processingState;

      // Debug Print for this stream (optional now, but can be useful)
      debugPrint(
          "AudioPlayerHandler: PlaybackEvent: state=$processingState, "
          "playing=$playing, "
          "buff=${event.bufferedPosition}" // Note: Not logging position here anymore
          );

      playbackState.add(playbackState.value.copyWith(
        controls: _getControls(playing, processingState),
        systemActions: const { MediaAction.seek }, // Ensure seek is enabled
        processingState: _getAudioServiceProcessingState(processingState),
        playing: playing,
        // *** updatePosition is now handled by the positionStream listener below ***
        bufferedPosition: event.bufferedPosition, // Get buffer updates here
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    }, onError: (Object e, StackTrace stackTrace) {
      // ... (error handling as before)
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorMessage: 'Player error: $e',
      ));
      debugPrint('AUDIO HANDLER ERROR: $e \n$stackTrace');
    });

    // --- Listener 2: SPECIFICALLY for live position updates (from positionStream) ---
    _player.positionStream.listen((position) {
      // Debug print for this stream
      //debugPrint("AudioPlayerHandler: PositionStream: pos=$position");

      // Update ONLY the position in the playbackState
      // Use the latest playbackState.value as the base
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
    // ------------------------------------------------------------------------------

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      // ... (duration handling as before - update mediaItem)
       final currentMediaItem = mediaItem.value;
      if (currentMediaItem != null && duration != null) {
        mediaItem.add(currentMediaItem.copyWith(duration: duration));
      }
    });

    // Initial idle state
    playbackState.add(playbackState.value.copyWith(
      // ... (initial idle state as before)
      controls: [MediaControl.play, MediaControl.stop],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
    ));
  }

  // --- Helper Methods (_getAudioServiceProcessingState, _getControls) ---
  // ... (Keep these exactly as they were in the previous version) ...
  AudioProcessingState _getAudioServiceProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
      default: return AudioProcessingState.error;
    }
  }

  List<MediaControl> _getControls(bool isPlaying, ProcessingState processingState) {
    if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
      return [MediaControl.stop];
    }
    if (isPlaying) {
      return [MediaControl.pause, MediaControl.stop];
    } else {
      if (processingState == ProcessingState.ready || processingState == ProcessingState.completed) {
        return [MediaControl.play, MediaControl.stop];
      }
      return [MediaControl.play, MediaControl.stop];
    }
  }


  // --- Getters (isLoading, isPlaying, isCurrentlyPlaying) ---
  // ... (Keep these exactly as they were in the previous version) ...
  bool get isLoading => _player.playerState.processingState == ProcessingState.loading || _player.playerState.processingState == ProcessingState.buffering;
  bool get isPlaying => _player.playing;
  String get isCurrentlyPlaying => mediaItem.value?.title ?? "Nothing is loaded...";

  // --- Overridden Methods (setMediaItem, play, pause, stop, seek, onTaskRemoved) ---
  // ... (Keep these exactly as they were in the previous version, including the optimistic seek update) ...
   @override
  Future<void> setMediaItem(MediaItem newItem, {bool playWhenReady = false}) async {
    mediaItem.add(newItem);
    playbackState.add(playbackState.value.copyWith(
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      processingState: AudioProcessingState.loading,
    ));
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(newItem.id)));
      if (playWhenReady) {
        _player.play();
      }
    } catch (e) {
      debugPrint('Error setting audio source: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: 'Failed to load: ${e.toString()}',
      ));
    }
  }

  Future<void> customSetStream(MediaItem newItem) async {
    await setMediaItem(newItem, playWhenReady: true);
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint("AudioPlayerHandler: Attempting to seek to $position");
    // Optimistic UI update
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    try {
      await _player.seek(position);
      debugPrint("AudioPlayerHandler: Seek to $position completed by player.");
      // The positionStream listener should naturally pick up the new position.
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