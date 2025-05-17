import 'package:ctwr_midtown_radio_app/src/media_player/progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';

// the fullscreen player with the playback controls
class FullScreenPlayerModal extends StatefulWidget {
  const FullScreenPlayerModal({super.key});

  @override
  State<FullScreenPlayerModal> createState() => _FullScreenPlayerModalState();
}

class _FullScreenPlayerModalState extends State<FullScreenPlayerModal> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // increase lines if text gets larger so as to not cut off information -- for accessibility
    final textScale = MediaQuery.of(context).textScaler.scale(1);
    final maxLinesSession = (textScale > 1.5) ? 2 : 1;
    final maxLinesTitle = (textScale > 1.5) ? 3 : 2;
    final maxLinesArtist = (textScale > 1.5) ? 2 : 1;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,

      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;

        if (mediaItem == null) {
          return SizedBox(
            height: screenHeight, 
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final bool isLiveStream = mediaItem.isLive == true;
        // prefer 'icySession' from extras, then 'genre' as fallback for session display
        final String? sessionToDisplay = (mediaItem.extras?['icySession'] as String?)?.isNotEmpty == true
            ? "${mediaItem.extras!['icySession']}"
            : (mediaItem.genre?.isNotEmpty == true ? mediaItem.genre : null);

        // for live streams, title/artist will be updated by ICY
        final String displayTitle = mediaItem.title;
        final String? displayArtist = mediaItem.artist;

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,

          builder: (context, playbackStateSnapshot) {
            final playbackState = playbackStateSnapshot.data;
            final isPlaying = playbackState?.playing ?? false;
            final processingState = playbackState?.processingState ?? AudioProcessingState.idle;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
              child: Container(
                height: screenHeight,
                color: theme.scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          style: ButtonStyle(
                            fixedSize: WidgetStateProperty.all(
                              Size(48, 48),
                            ),
                            backgroundColor: WidgetStateProperty.all(
                              Colors.black.withAlpha((0.7 * 256).round()),
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 30, color: Colors.white),
                          tooltip: 'Minimize player',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                                     
                      // Image, 'session', song and artist
                      // if text is large, this becomes scrollable so as to not cut off information -- for accessibility
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: <Widget>[
                                    // Album art
                                    Semantics(
                                      image: true,
                                      label: mediaItem.artUri != null 
                                          ? "Album art for ${mediaItem.album ?? 'current track'}" 
                                          : "Midtown Radio Microphone Logo",
                                      child: Container(
                                        width: screenWidth * 0.65,
                                        height: screenWidth * 0.65,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(12.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(64),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                          image: mediaItem.artUri != null
                                          ? DecorationImage(
                                            
                                            image: NetworkImage(
                                              mediaItem.artUri.toString(),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                          : null,
                                        ),
                                        child: mediaItem.artUri == null
                                            ? Image.asset(
                                              'assets/images/logo_mic_black_on_white.png'
                                            )
                                            : null,
                                      ),
                                    ),
                
                                    // Text information block - session, song and artist all stacked
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ICY Session / Show Name Display (for Live)
                                        if (isLiveStream && sessionToDisplay != null && sessionToDisplay.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Text(
                                              sessionToDisplay,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                color: theme.colorScheme.onSurface.withAlpha((0.9 * 255).round()),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center, maxLines: maxLinesSession, overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                  
                                        Text(
                                          displayTitle,
                                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                          textAlign: TextAlign.center, maxLines: maxLinesTitle, overflow: TextOverflow.ellipsis,
                                        ),

                                        if (displayArtist != null && displayArtist.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              displayArtist,
                                              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round())),
                                              textAlign: TextAlign.center, maxLines: maxLinesArtist, overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        ),
                      ),

                      // Progress bar or Live indicator
                      if (!isLiveStream) 
                        ProgressBar(
                            showTimestamps: true,
                            trackHeight: 3.0,
                            //thumbRadius: 7.0,
                          )
                      else 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0), 
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
                
                      const SizedBox(height: 20),
                
                      // Playback controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // previous button
                            StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (context, snapshot) {
                                final bool canSkipPrevious = snapshot.data?.controls.any((control) => control == MediaControl.skipToPrevious) ?? false;
                                return IconButton(
                                  tooltip: "Skip to Previous Track",
                                  icon: const Icon(Icons.skip_previous), iconSize: 42,
                                  color: canSkipPrevious ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha((0.3 * 255).round()),
                                  onPressed: canSkipPrevious ? audioHandler.skipToPrevious : null,
                                );
                              }
                            ),
                            // play/pause button
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
                                  onPressed: () { 
                                    if (isPlaying) {
                                      audioHandler.pause();
                                    } else {
                                      audioHandler.play();
                                    }
                                  },
                                ),
                            ),
                            // next button
                            StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (context, snapshot) {
                                //debugPrint("controls: ${snapshot.data?.controls.toString()}");
                                final bool canSkipNext = snapshot.data?.controls.any((control) => control == MediaControl.skipToNext) ?? false;
                                return IconButton(
                                  tooltip: "Skip to Next Track",
                                  icon: const Icon(Icons.skip_next), iconSize: 42,
                                  color: canSkipNext ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha((0.3 * 255).round()),
                                  onPressed: canSkipNext ? audioHandler.skipToNext : null,
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
