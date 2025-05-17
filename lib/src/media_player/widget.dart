// lib/src/media_player/widget.dart
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:ctwr_midtown_radio_app/src/media_player/progress_bar.dart';
// import 'package:ctwr_midtown_radio_app/src/media_player/audio_player_handler.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/src/media_player/fullscreen_player_modal.dart';
import 'package:flutter/rendering.dart';

class PlayerWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<bool> isModalOpen;

  // I was thinking of adding swipe gestures to skip to next or previous, but have not been able to do it yet
  // so all of it is commented out for now.

  // static const double _horizontalSwipeThreshold = 75.0;
  // static const double _minSwipeVelocity = 200.0;
  
  const PlayerWidget({
    super.key,
    required this.navigatorKey,
    required this.isModalOpen,
  });

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {

  // gets called when user taps - brings up fullscreen player
  void _showFullScreenPlayer(BuildContext context) async {
    if (audioHandler.mediaItem.value == null) return;
    widget.isModalOpen.value = true;

    await showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      barrierColor: Colors.black.withAlpha(200),
      context: widget.navigatorKey.currentContext!,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builderContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
          child: DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollController) {
              return const FullScreenPlayerModal();
            },
          ),
        );
      },
    );
    widget.isModalOpen.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safePadding = mediaQuery.viewPadding.bottom;
    final theme = Theme.of(context);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaItemSnapshot) {
        //debugPrint("built ${mediaItemSnapshot.toString()}");
        final mediaItem = mediaItemSnapshot.data;
        final bool hasMedia = mediaItem != null;

        // Differentiate between live and on-demand for UI and different controls
        final bool isLiveStream = mediaItem?.isLive == true;
        // For display in bottom bar:
        // Primary: "Artist - Title" or just "Title" (from ICY for live, or regular for on-demand)
        // Secondary: "Session Name" (for live from ICY) or "Album Name" (for on-demand)
        
        String primaryDisplay = mediaItem?.title ?? "Nothing is loaded...";
        if (mediaItem?.artist?.isNotEmpty == true) {
          primaryDisplay = "${mediaItem!.artist} - ${mediaItem.title}";
        }

        String secondaryDisplay = "";
        if (isLiveStream) {
          secondaryDisplay = (mediaItem?.extras?['icySession'] as String?)?.isNotEmpty == true
              ? "LIVE • ${mediaItem!.extras!['icySession']}"
              : (mediaItem?.genre?.isNotEmpty == true ? mediaItem!.genre! : "LIVE");
        } else {
          secondaryDisplay = mediaItem?.album?.isNotEmpty == true ? mediaItem!.album! : "ON DEMAND";
        }

        return GestureDetector(
          onTap: hasMedia ? () => _showFullScreenPlayer(widget.navigatorKey.currentContext!) : null,
          
          // more stuff for drag to skip/previous -- to be implemented
          // onHorizontalDragEnd: !isLiveStream && hasMedia
          //     ? (details) {
          //         final currentPlaybackState = audioHandler.playbackState.value; // Get current playback state
          //         if (details.primaryVelocity != null && details.primaryVelocity!.abs() > _minSwipeVelocity) {
          //           // Check actual displacement as well to avoid accidental mini-drags
          //           // This check might be too simple; velocity is often better.
          //           // Let's rely mainly on velocity direction and magnitude for now.
        
          //           if (details.primaryVelocity! < -_minSwipeVelocity) { // Swiped Left (towards next)
          //             final bool canSkipNext = currentPlaybackState.controls.any((control) => control == MediaControl.skipToNext);
          //             if (canSkipNext) {
          //               audioHandler.skipToNext();
          //             }
          //           } else if (details.primaryVelocity! > _minSwipeVelocity) { // Swiped Right (towards previous)
          //             final bool canSkipPrevious = currentPlaybackState.controls.any((control) => control == MediaControl.skipToPrevious);
          //             if (canSkipPrevious) {
          //               audioHandler.skipToPrevious();
          //             }
          //           }
          //         }
          //       }
          //     : null,
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, playbackStateSnapshot) {
              final playbackState = playbackStateSnapshot.data;
              final isPlaying = playbackState?.playing ?? false;
              final isLoading = (playbackState?.processingState == AudioProcessingState.loading ||
                                 playbackState?.processingState == AudioProcessingState.buffering);
          
              return Container(
                padding: EdgeInsets.only(
                  top: 8.0, left: 8.0, right: 8.0,
                  bottom: safePadding > 0 ? safePadding : 8.0,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                  
                  // rounded? or straight? currently rounded but open to opinions
                  borderRadius: BorderRadiusDirectional.circular(16.0)
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: (isLoading)
                            ? const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(semanticsLabel: "Loading Playback",),
                              ),
                            )
                            : IconButton(
                                iconSize: 28,
                                icon: Semantics(
                                  label: isPlaying ? "Pause" : "Play",
                                  child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
                                ),
                                onPressed: () {
                                  if (primaryDisplay.isNotEmpty && primaryDisplay != "Nothing is loaded...") {
                                    if (isPlaying) {
                                      audioHandler.pause();
                                    } else {
                                      audioHandler.play();
                                    }
                                  }
                                },
                              ),
                        ),
                        
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // secondary display line (Session/Album/LIVE)
                              // smaller, lighter, above main line
                              if (secondaryDisplay.isNotEmpty)
                                Text(
                                  secondaryDisplay,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: theme.textTheme.bodySmall?.color?.withAlpha((0.7 * 256).round()),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
          
                              // Primary display line (Artist - Title or just Title)
                              Text(
                                primaryDisplay,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
          
                        // Optional: Visual cue for swiping if not live
                        // if (!isLiveStream && (playbackState?.controls.any((c) => c == MediaControl.skipToNext || c == MediaControl.skipToPrevious) ?? false))
                        //     Icon(Icons.swap_horiz_rounded, color: theme.iconTheme.color?.withAlpha((0.4 * 256).round()), size: 22)
                        // else
                        //     const SizedBox(width:22), // Maintain space
                        
                        const SizedBox(width: 8),
                      ],
                    ),
                    if (!isLiveStream && hasMedia)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0).copyWith(top: 4.0),
                        
                        // here the user cannot interact - it just shows the progress
                        // if they tap or try to interact it brings up fullscreen player where they can seek
                        child: ProgressBar(
                          showTimestamps: false,
                          trackHeight: 3.0,
                          thumbRadius: 0.0,
                        ),
                      )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
