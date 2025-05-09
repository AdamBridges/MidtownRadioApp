import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ctwr_midtown_radio_app/main.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  Stream<_PositionData> get _positionDataStream =>
      Rx.combineLatest3<MediaItem?, Duration, PlaybackState, _PositionData>(
        audioHandler.mediaItem,
        AudioService.position,
        audioHandler.playbackState,
        (mediaItem, position, playbackState) => _PositionData(
          mediaItem: mediaItem,
          position: position,
          isLive: mediaItem?.extras?['isLive'] == true || mediaItem?.duration == null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<_PositionData>(
      stream: _positionDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data;

        if (data == null || data.isLive) {
          return const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              "🔴 On live",
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final duration = data.mediaItem?.duration ?? Duration.zero;
        final position = data.position;

        return Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            color: theme.primaryColor,
          ),
        );
      },
    );
  }
}

class _PositionData {
  final MediaItem? mediaItem;
  final Duration position;
  final bool isLive;

  _PositionData({
    required this.mediaItem,
    required this.position,
    required this.isLive,
  });
}