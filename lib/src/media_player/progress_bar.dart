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
    this.thumbRadius = 8.0,
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
                    thumbShape: _CustomThumbShape(
                      visualRadius: widget.thumbRadius,
                      // touch radius is always 16 (32 height) for accessibility, despite appearing smaller
                      touchRadius: 16.0,
                    ),

                    overlayShape: RoundSliderOverlayShape(overlayRadius: widget.thumbRadius + 8.0),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.onSurface.withAlpha((0.2 * 255).round()),
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withAlpha((0.2 * 255).round()),
                    trackShape: const RoundedRectSliderTrackShape(),
                    disabledActiveTrackColor: theme.colorScheme.primary
                  ),
                  child : Semantics(
                    label: "Progress bar",
                    value: "${formatDuration(positionToDisplay)} of ${formatDuration(totalDuration)}",
                    child: MergeSemantics(
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (ActivateIntent intent) {
                              audioHandler.seek(positionToDisplay + const Duration(seconds: 10));
                              return null;
                            },
                          ),
                          ScrollIntent: CallbackAction<ScrollIntent>(
                            onInvoke: (ScrollIntent intent) {
                              if (intent.direction == AxisDirection.right) {
                                audioHandler.seek(positionToDisplay + const Duration(seconds: 10));
                              } else if (intent.direction == AxisDirection.left) {
                                audioHandler.seek(positionToDisplay - const Duration(seconds: 10));
                              }
                              return null;
                            },
                          ),
                        },
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
                    ),
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

// allows us to have visitble tap area and a touchable tap area which is different
class _CustomThumbShape extends SliderComponentShape {
  final double visualRadius;
  final double touchRadius;

  const _CustomThumbShape({
    required this.visualRadius,
    required this.touchRadius,
  });

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.blue
      ..style = PaintingStyle.fill;

    // Draw the actual visible thumb (4px)
    canvas.drawCircle(center, visualRadius, paint);
  }

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(touchRadius); // Larger hit test area
  }
}
