import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:ctwr_midtown_radio_app/src/media_player/format_duration.dart';

// Progress/seek bar for on demand audio

class ProgressBar extends StatefulWidget {
  final bool showTimestamps;
  final double trackHeight;
  final double thumbRadius;

  const ProgressBar({
    super.key,
    this.showTimestamps = true,
    this.trackHeight = 3.0,
    this.thumbRadius = 7.0,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  bool _isUserDraggingSlider = false;
  double? _userDragValueMilliseconds;

  // to detect when media item changes to reset drag state
  String? _currentMediaItemId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem, 
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;
        final totalDuration = mediaItem?.duration;

        // reset dragging state if media item changes
        if (mediaItem?.id != _currentMediaItemId) {
          _currentMediaItemId = mediaItem?.id;
          // if we were dragging, cancel it because the track changed
          if (_isUserDraggingSlider) {
            // use WidgetsBinding to schedule state update after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isUserDraggingSlider = false;
                  _userDragValueMilliseconds = null;
                });
              }
            });
          }
        }

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,

          builder: (context, playbackStateSnapshot) {
            final playbackState = playbackStateSnapshot.data;
            final streamPosition = playbackState?.position ?? Duration.zero;

            double currentPositionMilliseconds = streamPosition.inMilliseconds.toDouble();
            double totalDurationMilliseconds = totalDuration?.inMilliseconds.toDouble() ?? 0.0;

            if (_isUserDraggingSlider && _userDragValueMilliseconds! > totalDurationMilliseconds) {
                totalDurationMilliseconds = _userDragValueMilliseconds!;
            }
            if (totalDurationMilliseconds <= 0.0) totalDurationMilliseconds = 1.0;

            final double displaySliderValue = _isUserDraggingSlider
                ? _userDragValueMilliseconds!
                : currentPositionMilliseconds.clamp(0.0, totalDurationMilliseconds);
            
            final Duration positionToDisplay = _isUserDraggingSlider
                ? Duration(milliseconds: _userDragValueMilliseconds!.round())
                : streamPosition;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // styled slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: widget.trackHeight,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: widget.thumbRadius),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: widget.thumbRadius + 8.0),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.onSurface.withAlpha((0.2 * 255).round()),
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withAlpha((0.2 * 255).round()),
                    trackShape: const RoundedRectSliderTrackShape(),
                    disabledActiveTrackColor: theme.colorScheme.primary
                  ),
                  child: Slider(
                    value: displaySliderValue.isNaN || displaySliderValue.isInfinite
                        ? 0.0
                        : displaySliderValue.clamp(0.0, totalDurationMilliseconds),
                    
                    min: 0.0,
                    max: totalDurationMilliseconds,
                    
                    // for updating state  -- called when user starts dragging
                    onChangeStart: (totalDuration != null && (widget.thumbRadius >= 1.0 || widget.showTimestamps))
                      ? (value) {
                          setState(() {
                            _isUserDraggingSlider = true;
                            _userDragValueMilliseconds = value;
                          });
                        }
                      : null,
                    
                    // for updating state  -- called when user ends dragging, picks their finger up
                    onChangeEnd: (totalDuration != null && (widget.thumbRadius >= 1.0 || widget.showTimestamps))
                      ? (value) {
                          audioHandler.seek(Duration(milliseconds: value.round()));
                          if (mounted) {
                            setState(() {
                              _isUserDraggingSlider = false;
                            });
                          }
                        }
                      : null,

                    // called when user drags to new value
                    onChanged: (totalDuration != null && (widget.thumbRadius >= 1.0 || widget.showTimestamps))
                      ? (value) {
                          setState(() {
                            _userDragValueMilliseconds = value;
                          });
                        }
                      : null,
                  ),
                ),

                if (widget.showTimestamps)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(positionToDisplay),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        Text(
                          formatDuration(totalDuration),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
