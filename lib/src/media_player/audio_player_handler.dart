//import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  bool _isLoading = false;
  bool _isPlaying = false;
  String _isCurrentlyPlaying = "Nothing is loaded...";

  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  String get isCurrentlyPlaying => _isCurrentlyPlaying;

  AudioPlayerHandler() {
    playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.stop, 
          _isPlaying
            ? MediaControl.pause
            : MediaControl.play
          ],
        androidCompactActionIndices: [0,1],
        processingState: AudioProcessingState.loading));
  }

setStream(MediaItem item) {
  //debugPrint("Attempting to load URL: ${item.id} for title: ${item.title}");
  _isLoading = true;
  mediaItem.add(item);
  // Ensure you're updating your UI to reflect loading state
  _isCurrentlyPlaying = "Loading: ${item.title}";
  playbackState.add(playbackState.value.copyWith(
    processingState: AudioProcessingState.loading,
  ));

  _player.setUrl(item.id).then((_) {
    _isCurrentlyPlaying = item.title;
    _isLoading = false;
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.ready,
    ));
    //debugPrint("URL loaded successfully: ${item.id}");
    play(); // Call play after successful loading
  }).catchError((error, stackTrace) { // Catch the error
    _isCurrentlyPlaying = "Error: Could not load audio; Check internet.";
    _isLoading = false;
    _isPlaying = false;
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.error,
      playing: false,
    ));

  });
}

  @override
  Future<void> play() async {
    _isPlaying = true;
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.pause],
    ));
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.play],
    ));
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _isCurrentlyPlaying = "Nothing is loaded...";
    _isLoading = false;
    _isPlaying = false;
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle
    ));
  }
}
