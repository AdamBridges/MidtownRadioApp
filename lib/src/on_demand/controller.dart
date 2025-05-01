import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

// For debugprint
import 'package:flutter/foundation.dart'; 


class OnDemand {
  List<Episode> episodes = [];
  final Map<String, Uint8List> _imageCache = {};

  OnDemand._();

  static Future<OnDemand> create() async {
    final onDemand = OnDemand._();
    await onDemand._fetchEpisodes();
    return onDemand;
  }

 
  Future _fetchEpisodes() async {
    // getStreams probably can be statically accessed, unless we had some future plans for it to expand significantly
    // This also now needs to be awaited
    final List<String> streams = await _Streams.getStreams();

    try {
      episodes.clear();
      for (var url in streams) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final feed = RssFeed.parse(response.body);
          final podcastName = feed.title ?? 'Untitled Podcast';
          final imageUrl = feed.image?.url ??
              (feed.itunes?.image?.href ??
                  'assets/images/logo_mic_black_on_white.png');

          if (!_imageCache.containsKey(podcastName) &&
              imageUrl.startsWith('http')) {
            final imageResponse = await http.get(Uri.parse(imageUrl));
            if (imageResponse.statusCode == 200) {
              _imageCache[podcastName] = imageResponse.bodyBytes;
            }
          }

          for (var item in feed.items) {
            if (_episodeExists(item.guid ?? '')) {
              continue;
            }

           final formattedDuration = _formatDuration(item.itunes?.duration);

            final episode = Episode(
              guid: item.guid ?? 'No GUID Provided',
              podcastName: podcastName,
              podcastImageUrl: imageUrl,
              episodeName: item.title ?? 'Untitled Episode',
              episodeDescription:
                  item.description ?? 'No description available',
              episodeStreamUrl: item.enclosure?.url ?? '',
              episodeDate: item.pubDate != null
                  ? DateFormat('MMM d, yyyy').format(
                      DateFormat("EEE, dd MMM yyyy HH:mm:ss Z")
                          .parse(item.pubDate!, true))
                  : 'No date available',
              episodeSortDate: item.pubDate != null
                  ? DateFormat('yyyy-MM-dd').format(
                      DateFormat("EEE, dd MMM yyyy HH:mm:ss Z")
                          .parse(item.pubDate!, true))
                  : 'No date available',
              duration: formattedDuration,
            );
            episodes.add(episode);
          }
        } else {
          throw Exception(
              'Failed to load RSS feed (${response.statusCode}): $url');
        }
      }

      episodes.sort(
        (a, b) => DateTime.parse(b.episodeSortDate)
            .compareTo(DateTime.parse(a.episodeSortDate)),
      );
    } catch (e) { // print('Error fetching RSS feed: $e');
      throw Exception('Error fetching RSS feed.');
    }
  }

  Duration? _parseDuration(String? raw) {
    if (raw == null) return null;

    try {
      final parts = raw.split(':').map(int.parse).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      } else if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      } else if (parts.length == 1) {
        return Duration(seconds: parts[0]);
      }
    } catch (_) {}

    return null;
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'No duration available';

    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  Uint8List? getCachedImage(String podcastName) {
    return _imageCache[podcastName];
  }

  bool _episodeExists(String guid) {
    return episodes.any((e) => e.guid == guid);
  }
}

class Podcast {
  final String title;
  final String description;
  final String imageUrl;
  final List<Episode> episodes;

  Podcast({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.episodes,
  });
}

class Episodes {
  List<Episode> episodes = [];
}

class Episode {
  final String podcastName;
  final String podcastImageUrl;
  final String episodeName;
  final String episodeDescription;
  final String episodeStreamUrl;
  final String episodeDate;
  final String episodeSortDate;
  final String guid;
  final String duration;

  Episode({
    required this.guid,
    required this.podcastName,
    required this.podcastImageUrl,
    required this.episodeName,
    required this.episodeDescription,
    required this.episodeStreamUrl,
    required this.episodeDate,
    required this.episodeSortDate,
    required this.duration,
  });
}

/*
We want the app to fetch streams from an external source which can be updated easily, 
so that when a podcast is added with a new RSS feed, the app updates.
Here is how we are getting the RSS streams to parse:

1. We have the hardcoded list of URLs for the podcasts that we already know of. 
   This is a fallback -- it wont update automatically if a new podcast is added.

2. We fetch a text file from an external source containing all current RSS URL's.
   We parse it for the URL's, and any new ones not already in the hardcoded list are added to our streams

We could maybe discuss persisting any newly found URL's onto the users device using Flutter shared_preferences or similar - though I don't see much benefit in this.
We also might as well update the hardcoded list anytime we would have had to push an update anyways for another reason - but I think theres no point to making an update solely to update the list.

Currently for testing, the file is on GitHub, but the plan is that it is on the existing Wix website for easy updating and more centralization.
*/
class _Streams {

  // This is the URL to the text file with updated RSS feeds
  // currently on GitHub -- TODO: move to Wix
  static const String feedsUrl = 
    'https://raw.githubusercontent.com/USERNAME/REPO/main/feeds.txt';

  // Hardcoded list - exists if for some reason new feeds can't fetch.
  static const  List<String> _fallback = [
    'https://feeds.transistor.fm/midtown-radio',
    'https://feeds.transistor.fm/on-the-scene',
    'https://feeds.transistor.fm/makings-of-a-scene',
    'https://feeds.transistor.fm/midtown-conversations'
  ];

  // Get union of fallback and new loaded RSS URL's
  static Future<List<String>> getStreams() async {
    try {
      final resp = await http.get(Uri.parse(feedsUrl));
      if (resp.statusCode != 200) throw Exception();

      // parses response body, separates out URLS and removes any extra whitespace
      final List<String> remote = resp.body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

      // merge remote + fallback, preserve remote order
      final merged = <String>[];
      merged.addAll(remote);
      merged.addAll(_fallback.where((u) => !merged.contains(u)));

      return merged;

    } catch (_) {
      debugPrint('StreamsRepository: fallback to hard-coded streams');
      return _fallback;
    }
  }
}

