import 'package:ctwr_midtown_radio_app/src/media_player/progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/src/media_player/audio_player_handler.dart';
import 'package:ctwr_midtown_radio_app/main.dart';

class PlayerWidget extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final AudioPlayerHandler audioPlayerHandler;

  const PlayerWidget({
    super.key,
    required this.navigatorKey,
    required this.audioPlayerHandler,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safePadding = mediaQuery.viewPadding.bottom;
    final theme = Theme.of(context);

    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final isPlaying = audioPlayerHandler.isPlaying;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.only(
              top: 15.0,
              left: 8.0,
              right: 8.0,
              // bottom: 8.0, //safePadding, // + 30,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    snapshot.data?.processingState == AudioProcessingState.buffering
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: theme.iconTheme.color,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                audioHandler.pause();
                               } else if (audioPlayerHandler.isCurrentlyPlaying.isNotEmpty && audioPlayerHandler.isCurrentlyPlaying != "Nothing is loaded...") {
                      audioHandler.play();
                              }
                            },
                          ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                         Text("Now Playing:",
                         style: Theme.of(context).textTheme.labelSmall,
                         ),
                          Text(
                            audioPlayerHandler.isCurrentlyPlaying,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          ProgressBar(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}