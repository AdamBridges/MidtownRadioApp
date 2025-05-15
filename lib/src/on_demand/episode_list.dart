import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/controller.dart';

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
  // also manages loading state for UI progress indicatoes
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

    final double screenWidth = MediaQuery.of(context).size.width;
    // the height of the top part of the screen with the logo
    final double sliverExpandedHeight = screenWidth * 0.6;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(

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
              title: Text(
                widget.show.title,
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    // gradient so that title contrasts well even on light images
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha((0.1 * 256).round()),
                            Colors.black.withAlpha((0.5 * 256).round()),
                            Colors.black.withAlpha((0.8 * 256).round()),
                          ],
                          stops: [0.5, 0.6, 0.8, 1]
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.show.description != null && widget.show.description!.isNotEmpty) SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(child: Text(widget.show.description!)),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.only(bottom:8.0),
            child: Center(
              child: Text(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
                "Episodes"
                ),),
          ),),
          _episodes.isEmpty
              ? SliverFillRemaining(
                  child: Center(child: Text("No episodes found for ${widget.show.title}.")))
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
class _EpisodeListTile extends StatefulWidget {
  final Episode episode;
  const _EpisodeListTile({required this.episode});

  @override
  State<_EpisodeListTile> createState() => _EpisodeListTileState();
}

class _EpisodeListTileState extends State<_EpisodeListTile> {

  bool showFullDescription = false;

  @override
  Widget build(BuildContext context) {
    // Use episode-specific image if available, otherwise fallback to show's image
    final String imageUrlToDisplay = widget.episode.episodeSpecificImageUrl ?? widget.episode.podcastImageUrl;

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
          onTap: widget.episode.episodeStreamUrl.isNotEmpty ? () {
            // debugPrint("url: ${episode.episodeStreamUrl}");
            final toPlay = MediaItem(
                id: widget.episode.episodeStreamUrl,
                title: widget.episode.episodeName,
                album: widget.episode.podcastName,
                artUri: Uri.parse(imageUrlToDisplay),
                // duration: null,
                duration: widget.episode.duration != null && widget.episode.duration!.contains(':')
                  ? _parseDurationToSystem(widget.episode.duration!) 
                  : (widget.episode.duration != null ? Duration(seconds: int.tryParse(widget.episode.duration!) ?? 0) : null),
                extras: {'description': widget.episode.episodeDescription ?? ''}
              );
            // debugPrint("\n\nTo Play: $toPlay\n\n");
            audioPlayerHandler.customSetStream(
              toPlay
            );
          } : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, (
              widget.episode.episodeDescription != null && widget.episode.episodeDescription!.length < 240
            ) ? 12.0: 0),
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
                          Text(
                            widget.episode.episodeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined, 
                                size: 12, 
                                color: (Theme.of(context).brightness == Brightness.dark) ? Colors.grey[400] : Colors.grey[850]
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.episode.episodeDateForDisplay,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: (Theme.of(context).brightness == Brightness.dark) ? Colors.grey[400] : Colors.grey[850], fontSize: 11.5),
                              ),
                              if (widget.episode.duration != null && widget.episode.duration!.isNotEmpty) ...[
                                Text(" • ", style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark) ? Colors.grey[400] : Colors.grey[850], fontSize: 11.5)),
                                Icon(Icons.timer_outlined, size: 12, color: (Theme.of(context).brightness == Brightness.dark) ? Colors.grey[400] : Colors.grey[850]),
                                const SizedBox(width: 4),
                                Text(
                                  widget.episode.duration!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: (Theme.of(context).brightness == Brightness.dark) ? Colors.grey[400] : Colors.grey[850], fontSize: 11.5),
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

                      // image for that show
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
                if (widget.episode.episodeDescription != null && widget.episode.episodeDescription!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.episode.episodeDescription!,
                    maxLines: showFullDescription ? null : 3,
                    overflow: showFullDescription ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (widget.episode.episodeDescription != null && widget.episode.episodeDescription!.length >= 240) Center(
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shadowColor: WidgetStateProperty.all<Color>(Colors.transparent),
                      padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                    ),
                    onPressed: ()=>setState(() {
                      if (widget.episode.episodeDescription != null && widget.episode.episodeDescription!.length < 240) {
                        showFullDescription = true;
                      } else {
                        showFullDescription = !showFullDescription;
                      }
                  }), child: Text(showFullDescription ? "Show Less" : "Show More")),
                ),
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
