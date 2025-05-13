import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ctwr_midtown_radio_app/main.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  Stream<_PositionData?> get _positionDataStream =>
      Rx.combineLatest3<MediaItem?, Duration, PlaybackState, _PositionData?>(
        audioHandler.mediaItem,
        audioPlayerHandler.positionStream,
        audioHandler.playbackState,
        (mediaItem, position, playbackState) {
          if (mediaItem == null) return null;
          return _PositionData(
            mediaItem: mediaItem,
            position: position,
            isLive: mediaItem.extras?['isLive'] == true || mediaItem.duration == null,
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<_PositionData?>(
      stream: _positionDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data;

        if (data == null) {
          return const SizedBox.shrink();
        }

        if (data.isLive) {
          return const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              "🔴 On live",
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.red,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          );
        }

        final duration = data.mediaItem.duration ?? Duration.zero;
        final position = data.position;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Material(
                child: Slider(
                  min: 0.0,
                  max: duration.inMilliseconds.toDouble(),
                  value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                  onChanged: (value) {
                    final newPosition = Duration(milliseconds: value.toInt());
                    audioHandler.seek(newPosition);
                  },
                  activeColor: theme.primaryColor,
                  inactiveColor: Colors.grey[300],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PositionData {
  final MediaItem mediaItem;
  final Duration position;
  final bool isLive;

  _PositionData({
    required this.mediaItem,
    required this.position,
    required this.isLive,
  });
}