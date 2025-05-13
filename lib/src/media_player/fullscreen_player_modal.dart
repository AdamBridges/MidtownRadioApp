// lib/src/media_player/fullscreen_player_modal.dart
import 'dart:async';
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
  String? _previousMediaItemId;

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

        if (currentMediaItemId != _previousMediaItemId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isDraggingSlider) {
              setState(() {
                _isDraggingSlider = false;
                _sliderDragValue = null;
              });
            }
          });
          _previousMediaItemId = currentMediaItemId;
        }

        if (mediaItem == null) {
          return SizedBox(
            height: screenHeight * 0.92, // Keep height consistent
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final bool isLiveStream = mediaItem.extras?['isLiveStream'] == true;
        // Prefer 'icySession' from extras, then 'genre' as fallback for session display
        final String? sessionToDisplay = (mediaItem.extras?['icySession'] as String?)?.isNotEmpty == true
            ? mediaItem.extras!['icySession']
            : (mediaItem.genre?.isNotEmpty == true ? mediaItem.genre : null);

        // For live streams, title/artist will be updated by ICY. Initial title might be station name.
        final String displayTitle = mediaItem.title;
        final String? displayArtist = mediaItem.artist;


        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, playbackStateSnapshot) {
            final playbackState = playbackStateSnapshot.data;
            final isPlaying = playbackState?.playing ?? false;
            final processingState = playbackState?.processingState ?? AudioProcessingState.idle;
            final Duration streamPosition = playbackState?.position ?? Duration.zero;
            final Duration? totalDuration = mediaItem.duration;

            final double currentSliderValue = _isDraggingSlider
                ? _sliderDragValue!
                : (streamPosition.inMilliseconds.toDouble().clamp(
                    0.0,
                    totalDuration?.inMilliseconds.toDouble() ?? double.maxFinite));
            
            final double maxSliderValue = totalDuration?.inMilliseconds.toDouble() ?? 1.0;

            final Duration positionToDisplay = _isDraggingSlider
                ? Duration(milliseconds: _sliderDragValue!.round())
                : streamPosition;
            
            return ClipRRect( // Clip the entire modal content to the rounded shape
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
              child: Container( // This container provides a base background
                height: screenHeight * 0.92,
                color: theme.scaffoldBackgroundColor, // Fallback background if no art/blur
                child: Stack(
                  children: [
                    // Blurred Background Image (only if artUri exists)
                    if (mediaItem.artUri != null) ...[
                      Positioned.fill(
                        child: Image.network(
                          mediaItem.artUri.toString(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), // Don't show error, just empty
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                             color: Theme.of(context).brightness == Brightness.dark
                                   ? Colors.black.withOpacity(0.55) // Slightly increased opacity for better text contrast
                                   : Colors.white.withOpacity(0.25),// Slightly increased opacity
                          ),
                        ),
                      ),
                    ],

                    // Player Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // Drag handle (no changes from your version)
                          Container(
                            width: 50, height: 5, margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.colorScheme.surface.withOpacity(0.5), width: 0.5),
                            ),
                          ),
                          const Spacer(flex:1),

                          // Album Art (no changes from your version)
                          Hero( tag: mediaItem.id, child: Container( /* ... */ ) ),
                          const Spacer(flex:1),

                          // --- ICY Session / Show Name Display (for Live) ---
                          if (isLiveStream && sessionToDisplay != null && sessionToDisplay.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                sessionToDisplay,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          // --- End ICY Session Display ---

                           Text(
                            displayTitle, // Shows station name, then ICY title for live
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          if (displayArtist != null && displayArtist.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                displayArtist, // Shows ICY artist for live
                                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          
                          const Spacer(flex:2),

                          // --- Conditional Seek Bar and Time ---
                          if (!isLiveStream) // Only show for on-demand
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
                                    value: currentSliderValue.isNaN || currentSliderValue.isInfinite ? 0.0 : currentSliderValue,
                                    min: 0.0, max: maxSliderValue > 0 ? maxSliderValue : 1.0,
                                    onChangeStart: totalDuration != null ? (value) { setState(() { _isDraggingSlider = true; _sliderDragValue = value; }); } : null,
                                    onChanged: totalDuration != null ? (value) { setState(() { _sliderDragValue = value; }); } : null,
                                    onChangeEnd: totalDuration != null ? (value) {
                                      audioHandler.seek(Duration(milliseconds: value.round()));
                                      if (mounted) { setState(() { _isDraggingSlider = false; }); }
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
                            )
                          else // For Live Streams, show a "LIVE" indicator
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30.0), // Adjusted padding for visual balance
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.circle, color: Colors.redAccent.shade700, size: 12),
                                  const SizedBox(width: 8),
                                  Text(
                                    "LIVE",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold, color: Colors.redAccent.shade700, letterSpacing: 1.5
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // --- End Conditional Seek Bar ---
                          
                          const SizedBox(height: 20),

                          // Playback Controls (Next/Previous are conditional based on PlaybackState.controls)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround, // Use spaceAround for better distribution
                              children: [
                                // Previous Button
                                StreamBuilder<PlaybackState>(
                                  stream: audioHandler.playbackState,
                                  builder: (context, snapshot) {
                                    // isLiveStream check is now handled by AudioPlayerHandler populating controls
                                    final bool canSkipPrevious = snapshot.data?.controls.any((control) => control == MediaControl.skipToPrevious) ?? false;
                                    return IconButton(
                                      icon: const Icon(Icons.skip_previous), iconSize: 42,
                                      color: canSkipPrevious ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.3),
                                      onPressed: canSkipPrevious ? audioHandler.skipToPrevious : null,
                                      tooltip: "Previous",
                                    );
                                  }
                                ),
                                // Play/Pause Button
                                SizedBox(
                                  height: 70, width: 70,
                                  child: (processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering)
                                      ? Container(
                                          alignment: Alignment.center,
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3.0, color: theme.colorScheme.primary)),
                                          ),
                                        )
                                      : IconButton(
                                          padding: EdgeInsets.zero, alignment: Alignment.center,
                                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                          iconSize: 70, color: theme.colorScheme.primary,
                                          tooltip: isPlaying ? "Pause" : "Play",
                                          onPressed: () { if (isPlaying) audioHandler.pause(); else audioHandler.play(); },
                                        ),
                                ),
                                // Next Button
                                StreamBuilder<PlaybackState>(
                                  stream: audioHandler.playbackState,
                                  builder: (context, snapshot) {
                                    final bool canSkipNext = snapshot.data?.controls.any((control) => control == MediaControl.skipToNext) ?? false;
                                    return IconButton(
                                      icon: const Icon(Icons.skip_next), iconSize: 42,
                                      color: canSkipNext ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.3),
                                      onPressed: canSkipNext ? audioHandler.skipToNext : null,
                                      tooltip: "Next",
                                    );
                                  }
                                ),
                              ],
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