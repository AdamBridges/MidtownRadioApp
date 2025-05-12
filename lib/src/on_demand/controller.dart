import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// Consider adding html_unescape if you encounter many HTML entities like &amp;, &lt;, etc.
// import 'package:html_unescape/html_unescape.dart';

// Utility to strip HTML tags
String _stripHtmlIfNeeded(String? htmlText) {
  if (htmlText == null || htmlText.isEmpty) {
    return '';
  }
  // Regex to remove HTML tags.
  final RegExp htmlRegExp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: false);
  String strippedText = htmlText.replaceAll(htmlRegExp, '');

  // Optional: Decode HTML entities if you add the html_unescape package
  // var unescape = HtmlUnescape();
  // strippedText = unescape.convert(strippedText);

  // Replace common HTML entities manually if not using a package
  strippedText = strippedText.replaceAll('&nbsp;', ' ');
  strippedText = strippedText.replaceAll('&amp;', '&');
  strippedText = strippedText.replaceAll('&lt;', '<');
  strippedText = strippedText.replaceAll('&gt;', '>');
  strippedText = strippedText.replaceAll('&quot;', '"');
  strippedText = strippedText.replaceAll('&#39;', "'");
  // Add more entities as needed

  return strippedText.trim();
}


// Represents a single Podcast Show/Series
class PodcastShow {
  final String title;
  final String? description;
  final String imageUrl;
  final String? publishDate;
  final DateTime? sortablePublishDate;
  final List<Episode> episodes;
  final String feedUrl; // Unique identifier for Hero animation

  PodcastShow({
    required this.title,
    this.description,
    required this.imageUrl,
    this.publishDate,
    this.sortablePublishDate,
    required this.episodes,
    required this.feedUrl,
  });
}

class Episode {
  final String guid;
  final String podcastName;
  final String podcastImageUrl; // Show's image, as fallback
  final String? episodeSpecificImageUrl; // Episode's own image
  final String episodeName;
  final String? episodeDescription;
  final String episodeStreamUrl;
  final String episodeDateForDisplay;
  final DateTime? episodeDateForSorting;
  final String? duration; // e.g., "HH:MM:SS" or total seconds as string

  Episode({
    required this.guid,
    required this.podcastName,
    required this.podcastImageUrl,
    this.episodeSpecificImageUrl,
    required this.episodeName,
    this.episodeDescription,
    required this.episodeStreamUrl,
    required this.episodeDateForDisplay,
    required this.episodeDateForSorting,
    this.duration,
  });
}

class OnDemand {
  List<PodcastShow> shows = [];

  OnDemand._();

  static Future<OnDemand> create() async {
    final onDemand = OnDemand._();
    await onDemand._fetchShows();
    return onDemand;
  }

  DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    List<String> patterns = [
      "EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
      "EEE, dd MMM yyyy HH:mm:ss 'UT'", "yyyy-MM-dd'T'HH:mm:ssZ",
      "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "dd MMM yyyy HH:mm:ss Z",
    ];
    for (String pattern in patterns) {
      try {
        return DateFormat(pattern, 'en_US').parse(dateString, true);
      } catch (_) {}
    }
    try { return DateTime.parse(dateString); } catch (_) {}
    return null;
  }

  String _formatDuration(String? itunesDuration) {
    if (itunesDuration == null || itunesDuration.isEmpty) return '';
    try {
      final int totalSeconds = int.parse(itunesDuration);
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int seconds = totalSeconds % 60;
      if (hours > 0) {
        return "${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      } else if (minutes > 0) {
        return "${minutes.toString()}:${seconds.toString().padLeft(2, '0')}";
      } else {
        return "${seconds.toString()}s";
      }
    } catch (e) {
      // If it's not just seconds (e.g., HH:MM:SS format already)
      if (itunesDuration.contains(':')) return itunesDuration;
      return '';
    }
  }


  Future<void> _fetchShows() async {
    final List<String> streamUrls = await _Streams.getStreams();
    shows.clear();

    for (var url in streamUrls) {
      try {
        debugPrint("Fetching feed: $url");
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final feed = RssFeed.parse(response.body);

          final String showTitle = feed.title ?? 'Untitled Show';
          // Use _stripHtmlIfNeeded for show description as well
          final String? showDescription = _stripHtmlIfNeeded(feed.description ?? feed.itunes?.summary);
          final String showImageUrl = feed.image?.url ??
              feed.itunes?.image?.href ??
              'assets/images/logo_mic_black_on_white.png';
          final String? channelPubDateString = feed.pubDate ?? feed.lastBuildDate;
          final DateTime? channelSortablePubDate = _parseDate(channelPubDateString);

          List<Episode> currentShowEpisodes = [];
          for (var item in feed.items) {
            final DateTime? episodeSortDate = _parseDate(item.pubDate);
            String episodeDisplayDate = 'Date unavailable';
            if (episodeSortDate != null) {
              episodeDisplayDate = DateFormat('MMM d, yyyy').format(episodeSortDate);
            } else if (item.pubDate != null) {
              episodeDisplayDate = item.pubDate!;
            }

            // Get episode description from <content:encoded> or <description> or <itunes:summary>
            String rawDescription = item.content?.value ?? item.description ?? item.itunes?.summary ?? '';
            String cleanedDescription = _stripHtmlIfNeeded(rawDescription);

            currentShowEpisodes.add(Episode(
              guid: item.guid ?? 'no_guid_${item.title}_${DateTime.now().millisecondsSinceEpoch}',
              podcastName: showTitle,
              podcastImageUrl: showImageUrl, // Show image as fallback
              episodeSpecificImageUrl: item.itunes?.image?.href, // Episode-specific image
              episodeName: item.title ?? 'Untitled Episode',
              episodeDescription: cleanedDescription,
              episodeStreamUrl: item.enclosure?.url ?? '',
              episodeDateForDisplay: episodeDisplayDate,
              episodeDateForSorting: episodeSortDate,
              duration: _formatDuration(item.itunes?.duration.toString()),
            ));
          }

          currentShowEpisodes.sort((a, b) {
            if (a.episodeDateForSorting == null && b.episodeDateForSorting == null) return 0;
            if (a.episodeDateForSorting == null) return 1;
            if (b.episodeDateForSorting == null) return -1;
            return b.episodeDateForSorting!.compareTo(a.episodeDateForSorting!);
          });

          shows.add(PodcastShow(
            title: showTitle,
            description: showDescription, // Cleaned show description
            imageUrl: showImageUrl,
            publishDate: channelPubDateString,
            sortablePublishDate: channelSortablePubDate,
            episodes: currentShowEpisodes,
            feedUrl: url, // Use feedUrl as a unique ID for Hero
          ));
        } else {
          debugPrint('Failed to load RSS feed ($url): ${response.statusCode}');
        }
      } catch (e, s) {
        debugPrint('Error processing RSS feed ($url): $e\n$s');
      }
    }

    shows.sort((a, b) {
      if (a.sortablePublishDate == null && b.sortablePublishDate == null) {
        return a.title.compareTo(b.title);
      }
      if (a.sortablePublishDate == null) return 1;
      if (b.sortablePublishDate == null) return -1;
      return b.sortablePublishDate!.compareTo(a.sortablePublishDate!);
    });
    debugPrint("Fetched and processed ${shows.length} shows.");
  }
}

class _Streams { // Keep your _Streams class as is
  static const String feedsUrl =
      'https://raw.githubusercontent.com/CivicTechWR/MidtownRadioApp/cw-dynamic-feeds/assets/tempfeeds.txt';
  static const List<String> _fallback = [
    'https://feeds.transistor.fm/midtown-radio',
    'https://feeds.transistor.fm/on-the-scene',
    'https://feeds.transistor.fm/makings-of-a-scene',
    'https://feeds.transistor.fm/midtown-conversations'
  ];

  static Future<List<String>> getStreams() async {
    try {
      debugPrint("Fetching remote RSS feed URLs from $feedsUrl...");
      final resp = await http.get(Uri.parse(feedsUrl));
      if (resp.statusCode == 200) {
        final List<String> remote = resp.body
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && l.startsWith('http'))
            .toList();

        if (remote.isNotEmpty) {
            final remoteSet = Set<String>.from(remote);
            final mergedStreams = List<String>.from(remote);
            for (var fallbackUrl in _fallback) {
                if (!remoteSet.contains(fallbackUrl)) {
                    mergedStreams.add(fallbackUrl);
                }
            }
            debugPrint("Successfully fetched and merged ${mergedStreams.length} feed URLs.");
            return mergedStreams;
        } else {
            debugPrint("Remote feed URL list was empty. Using fallback: ${_fallback.length} URLs.");
            return _fallback;
        }
      } else {
        debugPrint('Failed to fetch remote feed URLs (Code: ${resp.statusCode}). Using fallback.');
        return _fallback;
      }
    } catch (e) {
      debugPrint('Error fetching remote feed URLs: $e. Using fallback.');
      return _fallback;
    }
  }
}
