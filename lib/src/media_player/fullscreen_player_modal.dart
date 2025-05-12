// lib/src/media_player/fullscreen_player_modal.dart
import 'dart:async'; // For Future.delayed - though we removed its use in onChangeEnd
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart'; // For your global audioHandler

class FullScreenPlayerModal extends StatefulWidget {
  const FullScreenPlayerModal({super.key});

  @override
  State<FullScreenPlayerModal> createState() => _FullScreenPlayerModalState();
}

class _FullScreenPlayerModalState extends State<FullScreenPlayerModal> {
  bool _isDraggingSlider = false;
  double? _sliderDragValue;
  String? _previousMediaItemId; // To detect track changes and reset slider state

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;
        final currentMediaItemId = mediaItem?.id;

        // --- Logic to reset drag state on track change ---
        if (currentMediaItemId != _previousMediaItemId) {
          // Track has changed, reset dragging state if it was active
          // Use a post-frame callback to safely call setState.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isDraggingSlider) {
              setState(() {
                _isDraggingSlider = false;
                _sliderDragValue = null; // Clear the specific drag value
              });
            }
          });
          _previousMediaItemId = currentMediaItemId;
        }
        // --- End reset logic ---

        if (mediaItem == null) {
          return SizedBox(
            height: screenHeight * 0.85,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState, // This stream *MUST* provide live position updates from your Handler
          builder: (context, playbackStateSnapshot) {
            final playbackState = playbackStateSnapshot.data;
            final isPlaying = playbackState?.playing ?? false;
            final processingState = playbackState?.processingState ?? AudioProcessingState.idle;
            
            // This is the live position from audioHandler.
            // If it's not updating live, or resets to zero on pause, the issue is in AudioPlayerHandler.
            final Duration streamPosition = playbackState?.position ?? Duration.zero;
            final Duration? totalDuration = mediaItem.duration;

            // Determine the slider's current value
            final double currentSliderValue = _isDraggingSlider
                ? _sliderDragValue!
                : (streamPosition.inMilliseconds.toDouble().clamp(
                    0.0, 
                    totalDuration?.inMilliseconds.toDouble() ?? double.maxFinite
                  ));
            
            final double maxSliderValue = totalDuration?.inMilliseconds.toDouble() ?? 1.0;

            // Determine the position to display in text (shows drag value during drag)
            final Duration positionToDisplay = _isDraggingSlider
                ? Duration(milliseconds: _sliderDragValue!.round())
                : streamPosition;

            Widget background = const SizedBox.shrink();
            if (mediaItem.artUri != null) {
              background = Image.network(
                mediaItem.artUri.toString(),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              );
            }
            
            return Container(
              height: screenHeight * 0.92,
              child: ClipRRect( 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)), // Ensures content respects modal shape
                child: Stack(
                  children: [
                    // Blurred Background setup
                    if (mediaItem.artUri != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.3,
                          child: background,
                        ),
                      ),
                    if (mediaItem.artUri != null)
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                             color: Theme.of(context).brightness == Brightness.dark
                                   ? Colors.black.withOpacity(0.4)
                                   : Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),

                    // Player Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // Drag handle
                          Container(
                            width: 50,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.surface.withOpacity(0.5),
                                width: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(flex:1),

                          // Album Art
                          Hero(
                            tag: mediaItem.id, // Ensure this tag is unique per item if it animates from a list
                            child: Container(
                              width: screenWidth * 0.65,
                              height: screenWidth * 0.65,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                image: mediaItem.artUri != null
                                    ? DecorationImage(
                                        image: NetworkImage(mediaItem.artUri.toString()),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: mediaItem.artUri == null
                                  ? Icon(Icons.music_note, size: 100, color: theme.iconTheme.color?.withOpacity(0.5) ?? Colors.grey)
                                  : null,
                            ),
                          ),
                          const Spacer(flex:1),

                          // Title and Artist
                           Text(
                            mediaItem.title,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (mediaItem.album != null && mediaItem.album!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                mediaItem.album!,
                                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          
                          const Spacer(flex:2),

                          // Seek Bar and Time
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 15.0),
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.2),
                                  thumbColor: theme.colorScheme.primary,
                                  overlayColor: theme.colorScheme.primary.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: currentSliderValue.isNaN || currentSliderValue.isInfinite 
                                         ? 0.0 
                                         : currentSliderValue,
                                  min: 0.0,
                                  max: maxSliderValue > 0 ? maxSliderValue : 1.0,
                                  
                                  onChangeStart: totalDuration != null ? (value) {
                                    setState(() {
                                      _isDraggingSlider = true;
                                      _sliderDragValue = value;
                                    });
                                  } : null,
                                  onChanged: totalDuration != null ? (value) {
                                    setState(() {
                                      _sliderDragValue = value;
                                    });
                                  } : null,
                                  onChangeEnd: totalDuration != null ? (value) {
                                    audioHandler.seek(Duration(milliseconds: value.round()));
                                    // No Future.delayed here. Let the stream update the slider's resting position.
                                    if (mounted) {
                                      setState(() {
                                        _isDraggingSlider = false;
                                        // _sliderDragValue is not nulled here; it will be ignored once _isDraggingSlider is false
                                      });
                                    }
                                  } : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(positionToDisplay), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                                    Text(_formatDuration(totalDuration), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Playback Controls
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: (processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering)
                                ? Container(
                                    // Consistent sizing for the indicator
                                    alignment: Alignment.center, // Center the indicator
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0), // Padding around indicator
                                      child: SizedBox(
                                        width: 50, height: 50, // Control indicator size relative to box
                                        child: CircularProgressIndicator(
                                            strokeWidth: 3.0,
                                            color: theme.colorScheme.primary),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    // ** ADD THESE PROPERTIES **
                                    padding: EdgeInsets.zero, // Remove default padding
                                    alignment: Alignment.center, // Ensure icon is centered
                                    constraints: BoxConstraints(), // Remove default size constraints (optional but can help)
                                    // ***********************
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                    ),
                                    iconSize: 70, // The visual size of the icon itself
                                    color: theme.colorScheme.primary,
                                    splashRadius: 35, // Make splash radius match half the explicit size (optional)
                                    tooltip: isPlaying ? "Pause" : "Play", // Accessibility
                                    onPressed: () {
                                      if (isPlaying) {
                                        audioHandler.pause();
                                      } else {
                                        audioHandler.play();
                                      }
                                    },
                                  ),
                          ),
                          const Spacer(flex:1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}