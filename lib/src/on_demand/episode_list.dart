import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/controller.dart';
/*
when refreshing from exercise page:
══╡ EXCEPTION CAUGHT BY FLUTTER FRAMEWORK ╞═════════════════════════════════════════════════════════
The following assertion was thrown during a service extension callback for
"ext.flutter.inspector.setSelectionById":
Id does not exist.

When the exception was thrown, this was the stack:
#0      WidgetInspectorService.toObject (package:flutter/src/widgets/widget_inspector.dart:1463:7)
#1      WidgetInspectorService.setSelectionById (package:flutter/src/widgets/widget_inspector.dart:1595:25)
#2      WidgetInspectorService._registerServiceExtensionWithArg.<anonymous closure>
(package:flutter/src/widgets/widget_inspector.dart:948:35)
#3      BindingBase.registerServiceExtension.<anonymous closure>
(package:flutter/src/foundation/binding.dart:960:32)
<asynchronous suspension>
#4      _runExtension.<anonymous closure> (dart:developer-patch/developer.dart:138:13)
<asynchronous suspension>
════════════════════════════════════════════════════════════════════════════════════════════════════
*/
/// This is the page that will show the list of episodes for a single show
/// typically directed from [OnDemandPage] (in on_demand/view.dart)
class EpisodeListPage extends StatefulWidget {
  final PodcastShow show;

  // corresponds to image in ondemand page to animate photo transition
  final String heroTag;

  static const routeName = '/episodes';
  final String title = 'Episodes';

  const EpisodeListPage({super.key, required this.show, required this.heroTag});

  @override
  State<EpisodeListPage> createState() => _EpisodeListPageState();
}

class _EpisodeListPageState extends State<EpisodeListPage> {
  
  // pagination vars
  late List<Episode> _episodes;
  int _itemsToLoad = 15;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // This has ALL the episodes, but we will take a few at a time to load
    _episodes = widget.show.episodes;
    
    // load more episodes when user is 300 pixels away from hitting the bottom, if there are more to load
    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
          !_isLoadingMore && _itemsToLoad < _episodes.length) {
        _loadMoreEpisodes();
      }
    });
  }

  // loads more and adds to bottom of list for pagination
  // also manages loading state for UI progress indicators
  void _loadMoreEpisodes() {
     if (!mounted || _isLoadingMore) return;
    setState(() { _isLoadingMore = true; });
    Future.delayed(const Duration(milliseconds: 100), () { 
      if (!mounted) return;
      setState(() {
        _itemsToLoad += 10;
        _isLoadingMore = false;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  
    // the ACTUAL episodes we are displaying - this will expand for pagination as user scrolls
    final List<Episode> displayedEpisodes = _episodes.take(_itemsToLoad).toList();

    // here we do some calculations based on text scale size so that 
    // text renders visibily and does not lose information if user increases size for accessibility
    // - if scale factor is greater than 1.5 we stack 2 lines for the appbar, instead of 1 line of text
    // - if we have 2 lines (ie. scale factor > 1.5) then we outline text so that it still contrasts on background image

    final double screenWidth = MediaQuery.of(context).size.width;
    final double sliverExpandedHeight = screenWidth * 0.6;

    final textScaleFactor = MediaQuery.of(context).textScaler.scale(1);

    // default is 1 line, and default toolbar height
    int appBarTitleMaxLines = 1;
    double currentToolbarHeight = kToolbarHeight;
    // debugPrint("appBarTitleMaxLines: ${appBarTitleMaxLines}");

    // increase to 2 lines for title if scale factor on text is > 1.5
    if (textScaleFactor > 1.5) { 
      appBarTitleMaxLines = 2;
      final topPad = MediaQuery.of(context).padding.top;
      // debugPrint("toppad: ${topPad}");

      // Increase toolbar height to accommodate two lines.
      currentToolbarHeight =  (appBarTitleMaxLines) * textScaleFactor * 16 + topPad;
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            toolbarHeight: currentToolbarHeight,

            // back button -- white on dark to always contrast with whatever image is behind it
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.7 * 256).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),

            expandedHeight: sliverExpandedHeight,
            floating: false,

            // Title stays pinned at the top, even when scrolling down
            pinned: true, 
            snap: false,
            elevation: 2.0,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsetsDirectional.only(start: 60.0, bottom: 16.0, end:60.0), // Adjust padding
              
              // text -- title of the show
              title: Stack(
                alignment: Alignment.center,
                children: [
                  // this is the outline on the title -- only shows if title is 2 lines tall
                  if (appBarTitleMaxLines > 1)
                    Text(
                      widget.show.title,
                      textAlign: TextAlign.center,
                      maxLines: appBarTitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        // fontsize scales automatically if user enables OS-side text scaling
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 2 * textScaleFactor
                          ..color = Colors.black.withAlpha((0.8 * 255).round()),
                      ),
                    ),

                  // the actual text title -- shows always
                  Text(
                    widget.show.title,
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: appBarTitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // background is image for the show
              // this gets animated from the preview image in the on demand page with "hero" effect
              background: Hero(
                tag: widget.heroTag,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.show.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
                    ),
                    // gradient from bottom so that title contrasts well even on light images
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha((0.4 * 255).round()),
                            Colors.black.withAlpha((0.7 * 255).round()),
                            Colors.black.withAlpha((0.8 * 255).round()),
                          ],
                          stops: const [
                            0.5,
                            0.7,
                            0.85,
                            1.0
                          ],
                        )
                      ),
                    ),

                    // gradient to contrast OS buttons at top with so its not white on white
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha((0.7 * 255).round()),
                            Colors.black.withAlpha((0.5 * 255).round()),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.1, 0.2],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _episodes.isEmpty
            ? SliverFillRemaining(
              child: Center(child: Text("No episodes found for ${widget.show.title}."))
            )
            // List of episodes
            : SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (index == displayedEpisodes.length && _isLoadingMore) {
                    return const Center( child: CircularProgressIndicator() );
                  }
                  if (index >= displayedEpisodes.length) return const SizedBox.shrink();
                  final Episode episode = displayedEpisodes[index];
                  return _EpisodeListTile(episode: episode);
                },
                childCount: displayedEpisodes.length + (_isLoadingMore && displayedEpisodes.length < _episodes.length ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }
}

// view of one single episode - clickable to set stream
class _EpisodeListTile extends StatelessWidget {
  final Episode episode;
  const _EpisodeListTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    // Use episode-specific image if available, otherwise fallback to show's image
    final String imageUrlToDisplay = episode.episodeSpecificImageUrl ?? episode.podcastImageUrl;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color? metadataColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    // number of text rows increases if text is made larger so that information is preserved, 
    // even at larger text sizes for accessibility
    final textScaler = MediaQuery.of(context).textScaler;
    final textScaleFactor = MediaQuery.of(context).textScaler.scale(1);

    // Scaled icon size with text
    const double baseMetadataIconSize = 12.0;
    final double scaledMetadataIconSize = textScaler.scale(baseMetadataIconSize);

    // Base font size for metadata, will be scaled by system if Text widget uses themed style
    const double baseMetadataFontSize = 11.5; 

    // Dynamic maxLines for title
    int titleMaxLines = 2;
    if (textScaleFactor > 1.7) {
      titleMaxLines = 4; 
    } else if (textScaleFactor > 1.3) {
      titleMaxLines = 3;
    }

    // Dynamic maxLines for description
    int descriptionMaxLines = 3;
    if (textScaleFactor > 1.7) {
      descriptionMaxLines = 5;
    } else if (textScaleFactor > 1.3) {
      descriptionMaxLines = 4;
    }

    return StreamBuilder<MediaItem?>(
    stream: audioHandler.mediaItem,
    builder: (context, snapshot) {
      final currentMediaItem = snapshot.data;
      final isSelected = currentMediaItem?.id == episode.episodeStreamUrl && episode.episodeStreamUrl.isNotEmpty;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        elevation: 1.5,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // ontap - set url and start playin'
          onTap: episode.episodeStreamUrl.isNotEmpty ? () {
            // debugPrint("url: ${episode.episodeStreamUrl}");
            final toPlay = MediaItem(
                id: episode.episodeStreamUrl,
                title: episode.episodeName,
                album: episode.podcastName,
                artUri: Uri.parse(imageUrlToDisplay),
                // duration: null,
                duration: episode.duration != null && episode.duration!.contains(':')
                  ? _parseDurationToSystem(episode.duration!) 
                  : (episode.duration != null ? Duration(seconds: int.tryParse(episode.duration!) ?? 0) : null),
                extras: {'description': episode.episodeDescription ?? ''}
              );
            // debugPrint("\n\nTo Play: $toPlay\n\n");

            // this starts playing episode
            audioPlayerHandler.customSetStream(
              toPlay
            );
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // episode title
                          Text(
                            episode.episodeName,
                            maxLines: titleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // date and duration
                          Wrap(
                              spacing: 4.0, 
                              runSpacing: 4.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // date Info - row keeps the icon and text together
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined, 
                                      size: scaledMetadataIconSize, 
                                      color: metadataColor
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        episode.episodeDateForDisplay,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: metadataColor, 
                                          fontSize: baseMetadataFontSize
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // duration Info (only if duration exists) - row keeps relevant icon with its text
                                if (episode.duration != null && episode.duration!.isNotEmpty) ...[
                                  Text("•", style: TextStyle(color: metadataColor, fontSize: baseMetadataFontSize)),

                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined, 
                                        size: scaledMetadataIconSize, 
                                        color: metadataColor
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          episode.duration!,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: metadataColor, 
                                            fontSize: baseMetadataFontSize
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      // image for that show -- right of title
                      child: Image.network(
                        imageUrlToDisplay,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[200],
                            child: Icon(Icons.image_not_supported_outlined, size: 30, color: Colors.grey[400]),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            width: 70,
                            height: 70,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.0, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // put description below title and image
                if (episode.episodeDescription != null && episode.episodeDescription!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    episode.episodeDescription!,
                    maxLines: descriptionMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (episode.episodeStreamUrl.isEmpty)
                  Padding( 
                    padding: EdgeInsets.all(8),
                    child: Text("audio unavailable")
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

   // Helper to parse duration string like "HH:MM:SS" or "MM:SS" to Duration object for audio_service
  Duration? _parseDurationToSystem(String durationString) {
    final parts = durationString.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 1) {
      return Duration(seconds: parts[0]);
    }
    return null;
  }
}
