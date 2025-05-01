import 'package:audio_service/audio_service.dart';
import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/controller.dart';

class OnDemandPage extends StatefulWidget {
  const OnDemandPage({super.key});
  static const routeName = '/on_demand';
  final String title = 'On Demand';

  @override
  State<OnDemandPage> createState() => _OnDemandPageState();
}

class _OnDemandPageState extends State<OnDemandPage> {
  late Future<OnDemand> onDemandFuture;

  List<String> filters = ['All'];
  late String selectedFilter;
 // List<Episode> _displayedEpisodes = [];
  int itemsToLoad = 10;
  bool isLoadingMore = false;
  bool _showBackToTop = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    onDemandFuture = OnDemand.create();
    selectedFilter = filters[0];
    _scrollController.addListener(() {
      // This logic determines whether or not to show the "back to top" button
      final bool shouldShow = _scrollController.offset > 100;
      // Only call setState if the state needs to change
        if (shouldShow != _showBackToTop) {
          setState(() {
            _showBackToTop = shouldShow;
          });
        }

      // If we are 200 pixels from the bottom, start loading more if were not already
      // I find this makes the UX much better than if we have to get to the very bottom to start loading, and has minimal performance cost
      // ^ very rarely does the user even see the loading icon, scrolling at a reasonable speed 
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200  &&
          !isLoadingMore) {
        _loadMoreEpisodes();
      }
    });
  }

  void _loadMoreEpisodes() {
    setState(() {
        isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        itemsToLoad += 10;
        isLoadingMore = false;
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
    return
        FutureBuilder(
      future: onDemandFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error fetching shows'));
        } else if (!snapshot.hasData) {
          return const Center(child: Text('No shows available'));
        } else {
          final onDemand = snapshot.data!;
          filters = [
            'All',
            ...onDemand.episodes.map((e) => e.podcastName).toSet()
          ];
          final filteredEpisodes = selectedFilter == filters[0]
              ? onDemand.episodes
              : onDemand.episodes
                  .where((episode) => episode.podcastName == selectedFilter)
                  .toList();

          return Scaffold(
            floatingActionButton: _showBackToTop
                ? FloatingActionButton(
                    onPressed: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Icon(Icons.arrow_upward),
                  )
                : null,
            body: Column(children: [
            DropdownButton<String>(
              value: selectedFilter, // Set the current value
              items: filters.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newSelectedFilter) {
                if (newSelectedFilter != null) {
                  setState(() {
                    selectedFilter = newSelectedFilter;
                    itemsToLoad = 10;
                  });
                }
              },
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: filteredEpisodes.take(itemsToLoad).length +
                    (!isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == itemsToLoad && isLoadingMore) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (index >= filteredEpisodes.length) {
                    return const SizedBox.shrink();
                  }

                  final Episode show = filteredEpisodes[index];
                  return _OnDemandListTile(
                    podcastName: show.podcastName,
                    podcastImageUrl: show.podcastImageUrl,
                    podcastEpisodeName: show.episodeName,
                    podcastEpisodeDate: show.episodeDate,
                    podcastEpisodeStreamUrl: show.episodeStreamUrl,
                    duration: show.duration,
                  );
                },
              ),
            )
          ]));
        }
      },
    );
  }
}

// Defines view for a single show in the list
class _OnDemandListTile extends StatelessWidget {
  // ignore: use_super_parameters
  const _OnDemandListTile({
    Key? key,
    required this.podcastName,
    required this.podcastImageUrl,
    required this.podcastEpisodeName,
    required this.podcastEpisodeDate,
    required this.podcastEpisodeStreamUrl,
    required this.duration,
  }) : super(key: key);

  final String podcastName;
  final String podcastImageUrl;
  final String podcastEpisodeName;
  final String podcastEpisodeDate;
  final String podcastEpisodeStreamUrl;
  final String duration;

  Duration _parseDuration(String duration) {
    final parts = duration.split(':').map(int.parse).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 1) {
      return Duration(seconds: parts[0]);
    } else {
      return Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,// Listen to the current media item
      builder: (context, snapshot) {
        final currentMediaItem = snapshot.data;
        final isSelected = currentMediaItem?.id == podcastEpisodeStreamUrl;

        return Column(
          children: [
            ListTile(
              leading: Image.network(podcastImageUrl),// cachedImage != null ? Image.memory(cachedImage) : Image.network(podcastImageUrl),
              title: Text(
                podcastEpisodeName,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(podcastName),
                  Text(podcastEpisodeDate),
                ],
              ),
              selected: isSelected,
              selectedTileColor: Theme.of(context).highlightColor,
              onTap: () => audioPlayerHandler.setStream(
                MediaItem(
                  id: podcastEpisodeStreamUrl,
                  title: podcastEpisodeName,
                  album: podcastName,
                  artUri: Uri.parse(podcastImageUrl),
                  duration: _parseDuration(duration),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}