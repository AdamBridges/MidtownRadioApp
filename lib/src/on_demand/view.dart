import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/controller.dart';
import 'package:intl/intl.dart';

class OnDemandPage extends StatefulWidget {
  const OnDemandPage({super.key});
  static const routeName = '/on_demand';
  final String title = 'On Demand';

  @override
  State<OnDemandPage> createState() => _OnDemandPageState();
}

class _OnDemandPageState extends State<OnDemandPage> {
  late Future<OnDemand> _onDemandFuture;

  @override
  void initState() {
    super.initState();
    _onDemandFuture = OnDemand.create();
  }

  String _formatShowDisplayDate(DateTime? sortableDate, String? originalDateString) {
    if (sortableDate != null) {
      return DateFormat('MMM d, yyyy').format(sortableDate);
    }
    if (originalDateString != null && originalDateString.isNotEmpty) {
      return originalDateString.length > 16 ? "${originalDateString.substring(0, 16)}..." : originalDateString;
    }
    return 'Date N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<OnDemand>(
        future: _onDemandFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("An unexpected error has occured. Please try again later."));
          } else if (!snapshot.hasData || snapshot.data!.shows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: const Center(child: Text('No shows available. \nPlease ensure you are connected to the internet.', textAlign: TextAlign.center,)),
            );
          } else {
            final List<PodcastShow> shows = snapshot.data!.shows;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: shows.length,
              itemBuilder: (context, index) {
                final show = shows[index];
                // Unique tag for Hero animation. Using feedUrl as it should be unique per show.
                final String heroTag = "showImage_${show.feedUrl}";
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  elevation: 2.5,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EpisodeListPage(show: show, heroTag: heroTag),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  show.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container( /* ... error placeholder ... */ );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center( /* ... loading indicator ... */ );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column( /* ... show title, desc, date ... */
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  show.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (show.description != null && show.description!.isNotEmpty)
                                  Text(
                                    show.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  'Updated: ${_formatShowDisplayDate(show.sortablePublishDate, show.publishDate)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class EpisodeListPage extends StatefulWidget {
  final PodcastShow show;
  final String heroTag; // For Hero animation

  const EpisodeListPage({super.key, required this.show, required this.heroTag});

  @override
  State<EpisodeListPage> createState() => _EpisodeListPageState();
}

class _EpisodeListPageState extends State<EpisodeListPage> {
  late List<Episode> _episodes;
  int _itemsToLoad = 15;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  // No _showBackToTop needed if using SliverAppBar's pinned nature

  @override
  void initState() {
    super.initState();
    _episodes = widget.show.episodes;
    _scrollController.addListener(() {
      if (!mounted) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
          !_isLoadingMore && _itemsToLoad < _episodes.length) {
        _loadMoreEpisodes();
      }
    });
  }

  void _loadMoreEpisodes() { /* ... same as before ... */
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
    final List<Episode> displayedEpisodes = _episodes.take(_itemsToLoad).toList();
    final double screenWidth = MediaQuery.of(context).size.width;
    final double sliverExpandedHeight = screenWidth * 0.6; // Adjust ratio as needed

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: sliverExpandedHeight,
            floating: false,
            pinned: true, // Title stays pinned at the top
            snap: false,
            elevation: 2.0,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true, // Or false, depending on desired alignment when collapsed
              titlePadding: const EdgeInsetsDirectional.only(start: 60.0, bottom: 16.0, end:60.0), // Adjust padding
              title: Text(
                widget.show.title,
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
                    // Optional: Add a gradient overlay for better text visibility on image
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.5, 0.7, 1.0],
                        ),
                      ),
                    ),
                     // You could put show description or other details here, absolutely positioned
                    if (widget.show.description != null && widget.show.description!.isNotEmpty)
                      Positioned(
                        bottom: 40, // Adjust based on title padding and desired layout
                        left: 16,
                        right: 16,
                        child: Text(
                          widget.show.description!,
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _episodes.isEmpty
              ? SliverFillRemaining(
                  child: Center(child: Text("No episodes found for ${widget.show.title}.")))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      if (index == displayedEpisodes.length && _isLoadingMore) {
                        return const Center( /* ... loading indicator ... */ );
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

class _EpisodeListTile extends StatelessWidget {
  final Episode episode;
  const _EpisodeListTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    // Use episode-specific image if available, otherwise fallback to show's image
    final String imageUrlToDisplay = episode.episodeSpecificImageUrl ?? episode.podcastImageUrl;

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
              onTap: episode.episodeStreamUrl.isNotEmpty ? () {
                //debugPrint("url: ${episode.episodeStreamUrl}");
                audioPlayerHandler.setStream( /* ... MediaItem setup ... */ 
                   MediaItem(
                    id: episode.episodeStreamUrl,
                    title: episode.episodeName,
                    album: episode.podcastName,
                    artUri: Uri.parse(imageUrlToDisplay), // Use the determined image URL
                    duration: episode.duration != null && episode.duration!.contains(':') // If duration is HH:MM:SS
                              ? _parseDurationToSystem(episode.duration!) 
                              : (episode.duration != null ? Duration(seconds: int.tryParse(episode.duration!) ?? 0) : null),
                    extras: {'description': episode.episodeDescription ?? ''}
                  )
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
                              Text(
                                episode.episodeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5, // Slightly larger title
                                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    episode.episodeDateForDisplay,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700], fontSize: 11.5),
                                  ),
                                  if (episode.duration != null && episode.duration!.isNotEmpty) ...[
                                    const Text(" • ", style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                                    Icon(Icons.timer_outlined, size: 12, color: Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      episode.duration!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700], fontSize: 11.5),
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
                    if (episode.episodeDescription != null && episode.episodeDescription!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        episode.episodeDescription!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5, color: Colors.black87),
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
    if (parts.length == 3) { // HH:MM:SS
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) { // MM:SS
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 1) { // SS (already handled by int.tryParse in MediaItem)
      return Duration(seconds: parts[0]);
    }
    return null;
  }
}
