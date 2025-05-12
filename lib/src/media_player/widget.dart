// lib/src/media_player/widget.dart
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/src/media_player/fullscreen_player_modal.dart'; // Import the new modal

class PlayerWidget extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<bool> isModalOpen;

  const PlayerWidget({
    super.key,
    required this.navigatorKey, // Keep the key if you use it elsewhere, but not needed for this fix
    required this.isModalOpen,
  });

  void _showFullScreenPlayer(BuildContext context) async {
    // Make sure there's a media item to display before showing the modal
    if (audioHandler.mediaItem.value == null) return;
    isModalOpen.value = true;

    await showModalBottomSheet(
      
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.0), // Adjust radius as you like
        ),
      ),
      
      barrierColor: Theme.of(context).scaffoldBackgroundColor,
      context: context,
      useRootNavigator: true, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builderContext) {

        // Note: Use builderContext provided by the builder here, NOT the original context.
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

    isModalOpen.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safePadding = mediaQuery.viewPadding.bottom;
    final theme = Theme.of(context);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final bool hasMedia = mediaItemSnapshot.data != null;

        // *** Use the context from the StreamBuilder here ***

        return GestureDetector(
          
          // *** Pass the validContext to the tap handler ***
          onTap: hasMedia ? () => _showFullScreenPlayer(navigatorKey.currentContext!) : null,
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) { // This inner context is also valid
              final playbackState = snapshot.data;
              final isPlaying = playbackState?.playing ?? false;
              final isLoading = (playbackState?.processingState == AudioProcessingState.loading ||
                                 playbackState?.processingState == AudioProcessingState.buffering) ||
                                 audioPlayerHandler.isLoading;

              final String currentTitle = mediaItemSnapshot.data?.title ?? audioPlayerHandler.isCurrentlyPlaying;

              return Container(
                padding: EdgeInsets.only(
                  top: 8.0,
                  left: 8.0,
                  right: 8.0,
                  bottom: safePadding > 0 ? safePadding : 8.0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.cardColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    (isLoading)
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                          )
                        : IconButton(
                            iconSize: 28,
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              if (currentTitle.isNotEmpty && currentTitle != "Nothing is loaded...") {
                                if (isPlaying) {
                                  audioHandler.pause();
                                } else {
                                  audioHandler.play();
                                }
                              }
                            },
                          ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Now Playing:",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)
                            ),
                          ),
                          Text(
                            currentTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              );
            },
          ),
        );
      }
    );
  }
}