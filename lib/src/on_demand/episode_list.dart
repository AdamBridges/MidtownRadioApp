import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/controller.dart';
import 'package:flutter/rendering.dart';
import 'package:readmore/readmore.dart';

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
            leading: IconButton(
              style: ButtonStyle(
                fixedSize: WidgetStateProperty.all(
                  Size(48, 48),
                ),
                backgroundColor: WidgetStateProperty.all(
                  Colors.black.withAlpha((0.7 * 256).round()),
                ),
              ),
              icon: const Icon(Icons.chevron_left, size: 30, color: Colors.white),
              tooltip: 'Back to Shows',
              onPressed: () => Navigator.of(context).pop(),
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
                    ExcludeSemantics(
                      child: Text(
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
                    ),
              
                  // the actual text title -- shows always
                  Semantics(
                    label: widget.show.title,
                    header: true,
                    child: Text(
                      widget.show.title,
                      style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white),
                      textAlign: TextAlign.center,
                      maxLines: appBarTitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    Semantics(
                      label: "Album art for ${widget.show.title}",
                      image: true,
                      child: Image.network(
                        excludeFromSemantics: true,
                        widget.show.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
                      ),
                    ),
                    // gradient from bottom so that title contrasts well even on light images
                    ExcludeSemantics(
                      child: Container(
                        
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
                    ),
                
                    // gradient to contrast OS buttons at top with so its not white on white
                    ExcludeSemantics(
                      child: Container(
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
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.show.description != null && widget.show.description!.isNotEmpty) SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ReadMoreText(
              widget.show.description!,
              trimLines: 3,   
              trimMode: TrimMode.Line,                 
              style: Theme.of(context).textTheme.bodyMedium!,
              trimCollapsedText: ' more',
              trimExpandedText: ' less',
              delimiter: '... ',
              textAlign: TextAlign.center,
            
              moreStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                
              ),
            
              lessStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.only(bottom:8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
                "Episodes"
                ),
            ),
          ),),
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
                  return _EpisodeListTile(episode: episode, show: widget.show);
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
class _EpisodeListTile extends StatefulWidget {
  final Episode episode;
  final PodcastShow show;
  const _EpisodeListTile({required this.episode, required this.show});

  @override
  State<_EpisodeListTile> createState() => _EpisodeListTileState();
}

class _EpisodeListTileState extends State<_EpisodeListTile> {

  @override
  Widget build(BuildContext context) {
    // Use episode-specific image if available, otherwise fallback to show's image
    final String imageUrlToDisplay = widget.episode.episodeSpecificImageUrl ?? widget.episode.podcastImageUrl;
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
      debugPrint("five");
      descriptionMaxLines = 5;
    } else if (textScaleFactor > 1.3) {
      descriptionMaxLines = 4;
            debugPrint("four");

    }


    return StreamBuilder<MediaItem?>(
    stream: audioHandler.mediaItem,
    builder: (context, snapshot) {
      final currentMediaItem = snapshot.data;
      final isSelected = currentMediaItem?.id == widget.episode.episodeStreamUrl && widget.episode.episodeStreamUrl.isNotEmpty;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        elevation: 1.5,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // ontap - set url and start playin'
          // Presuming in your widget you have access to:
// final PodcastShow currentShow; // The show object that widget.episode belongs to.
// final Episode selectedEpisode = widget.episode; // The specific episode tapped.
// And audioPlayerHandler is your AudioPlayerHandler instance.
// Also, ensure _parseDurationToSystem is accessible.

onTap: widget.episode.episodeStreamUrl.isNotEmpty ? () {
    // 1. Get all episodes from the current show.
    // Assuming 'currentShow' is available and has an 'episodes' list.
    final List<Episode> allEpisodesInShow = widget.show.episodes;

    // 2. Find the index of the selected episode.
    // Using guid for a more reliable match, assuming Episode has a unique guid.
    int selectedEpisodeIndex = allEpisodesInShow.indexWhere(
        (ep) => ep.guid == widget.episode.guid // Match by a unique ID like guid
    );

    if (selectedEpisodeIndex == -1) {
        // Fallback if guid isn't available or matching fails, try by stream URL or name, though less reliable.
        selectedEpisodeIndex = allEpisodesInShow.indexWhere(
            (ep) => ep.episodeStreamUrl == widget.episode.episodeStreamUrl
        );
        if (selectedEpisodeIndex == -1) {
            debugPrint("Error: Selected episode not found in the show's list. Cannot play.");
            // Optionally show a message to the user.
            return; 
        }
    }

    // 3. Convert all Episode objects in the show to MediaItem objects.
    List<MediaItem> mediaItemQueue = allEpisodesInShow.map((ep) {
        // Determine the image URL for this specific episode 'ep'.
        // Prefer episode-specific image, fallback to podcast image, then a generic placeholder.
        String artImageUrl = ep.episodeSpecificImageUrl ?? ep.podcastImageUrl;
        // Ensure the URL is valid and absolute.
        if (artImageUrl.isEmpty || !(artImageUrl.startsWith('http://') || artImageUrl.startsWith('https://'))) {
            artImageUrl = 'https://via.placeholder.com/150/000000/FFFFFF/?text=No+Art'; // A generic placeholder
        }
        
        // Parse duration string. Ensure _parseDurationToSystem is available in this scope.
        // If _parseDurationToSystem is part of your widget, call it as widget._parseDurationToSystem.
        // If it's a global/static utility, call it directly.
        Duration? episodeDuration;
        if (ep.duration != null) {
            if (ep.duration!.contains(':')) {
                // Assuming _parseDurationToSystem exists and is accessible:
                // episodeDuration = _parseDurationToSystem(ep.duration!);
                // If it's not available, you'll need to implement or import it.
                // For now, let's use a simplified version if _parseDurationToSystem is missing.
                 try {
                    final parts = ep.duration!.split(':');
                    if (parts.length == 2) {
                       episodeDuration = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
                    } else if (parts.length == 3) {
                       episodeDuration = Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: int.parse(parts[2]));
                    }
                 } catch (e) { /* ignore parsing error, duration will be null */ }

            } else {
                episodeDuration = Duration(seconds: int.tryParse(ep.duration!) ?? 0);
            }
        }


        return MediaItem(
            id: ep.episodeStreamUrl, // Crucial: This must be the actual stream URL.
            title: ep.episodeName,
            album: ep.podcastName, // This is usually the PodcastShow's title.
            artist: ep.podcastName, // Often the podcast show is the "artist" for episodes.
            artUri: Uri.parse(artImageUrl),
            duration: episodeDuration,
            extras: {
                'description': ep.episodeDescription ?? '',
                // You can add other relevant data from the Episode object here.
                'guid': ep.guid,
            },
            // Mark as not live, which is typical for podcast episodes.
            // isLive: false, // audio_service MediaItem defaults isLive to false
        );
    }).toList();

    // 4. Call the new method in AudioPlayerHandler.
    audioPlayerHandler.setPodcastShowQueue(
      mediaItemQueue,
      selectedEpisodeIndex,
      // playWhenReady: true is the default in setPodcastShowQueue
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
                            widget.episode.episodeName,
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
                                      semanticLabel: "Published",
                                      Icons.calendar_today_outlined, 
                                      size: scaledMetadataIconSize, 
                                      color: metadataColor
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        widget.episode.episodeDateForDisplay,
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
                                if (widget.episode.duration != null && widget.episode.duration!.isNotEmpty) ...[
                                  Text("•", style: TextStyle(color: metadataColor, fontSize: baseMetadataFontSize)),

                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        semanticLabel: "Duration",
                                        Icons.timer_outlined, 
                                        size: scaledMetadataIconSize, 
                                        color: metadataColor
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          widget.episode.duration!,
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
                if (widget.episode.episodeDescription != null && widget.episode.episodeDescription!.isNotEmpty) ...[
                  const SizedBox(height: 10),

                  // shows with "more" or "less" - cuts to 3 lines (more if text is larger), but expands to full size
                  ReadMoreText(

                    widget.episode.episodeDescription!, // The main text content
                    trimLines: descriptionMaxLines,   
                    trimMode: TrimMode.Line,                 
                    style: Theme.of(context).textTheme.bodyMedium!,
                    trimCollapsedText: ' more',
                    trimExpandedText: ' less',
                    delimiter: '... ',

                    moreStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),

                    lessStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                ],
                if (widget.episode.episodeStreamUrl.isEmpty)
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
