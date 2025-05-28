import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'dart:async';
import 'package:ctwr_midtown_radio_app/src/media_player/format_duration.dart';

// utility to strip HTML tags -- this could use a second look over
String _stripHtmlIfNeeded(String? htmlText) {
  if (htmlText == null || htmlText.isEmpty) {
    return '';
  }
  final RegExp htmlRegExp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: false);
  String strippedText = htmlText.replaceAll(htmlRegExp, '');
  return strippedText.trim();
}

/// represents a single podcast show/series
/// - *NOT any specific episode (see [Episode])
class PodcastShow {
  final String title;
  final String? description;
  final String imageUrl;
  final String? publishDate;
  final DateTime? sortablePublishDate;
  final List<Episode> episodes;
  final String feedUrl;

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

// a single episode for a show
class Episode {
  final String guid;
  final String podcastName;
  final String podcastImageUrl;
  final String? episodeSpecificImageUrl;
  final String episodeName;
  final String? episodeDescription;
  final String episodeStreamUrl;
  final String episodeDateForDisplay;
  final DateTime? episodeDateForSorting;
  final String? duration;

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

  // caching
  static OnDemand? _cachedInstance; // Holds the cached instance
  static DateTime? _lastFetchTime;  // Timestamp of the last successful fetch
  static final Duration _cacheValidityDuration = const Duration(hours: 1); // How long cache is considered fresh
  
  static bool _isFetching = false; // Flag to prevent concurrent fetches
  static Completer<OnDemand>? _fetchCompleter; // Completer for ongoing fetch

  OnDemand._(); // Private constructor to ensure singleton-like access via create()

  // Static factory method to get or create the OnDemand instance
  static Future<OnDemand> create({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // If a fetch is already in progress, return its future to avoid duplicate work
    if (_isFetching && _fetchCompleter != null) {
      // debugPrint("OnDemand.create: Fetch already in progress. Awaiting existing operation.");
      return _fetchCompleter!.future;
    }

    // Check if cached data is available and still valid
    if (!forceRefresh &&
        _cachedInstance != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _cacheValidityDuration) {
      // debugPrint("OnDemand.create: Returning valid cached instance.");
      return _cachedInstance!;
    }

    // If cache is invalid, expired, or refresh is forced, fetch new data
    // debugPrint("OnDemand.create: Cache MISS or REFRESH forced. Initiating fetch...");
    _isFetching = true;
    _fetchCompleter = Completer<OnDemand>(); // Create a new completer for this fetch operation

    try {
      // create new instance and populate
      final newInstance = OnDemand._();
      await newInstance._fetchShows();
      
      _cachedInstance = newInstance;
      _lastFetchTime = DateTime.now();
      
      // debugPrint("OnDemand.create: Data fetched and cached successfully. Shows: ${_cachedInstance!.shows.length}");
      _fetchCompleter!.complete(_cachedInstance);
      return _cachedInstance!;
    } catch (e, s) {
      // debugPrint("OnDemand.create: Error during fetch operation: $e\n$s");
      // If fetch fails but an old cached instance exists, complete with old data
      if (_cachedInstance != null) {
        // debugPrint("OnDemand.create: Fetch failed. Returning stale cached data.");
        _fetchCompleter!.completeError(e, s);
        return _cachedInstance!;
      }
      // If no cached data and fetch fails, complete with error and rethrow
      _fetchCompleter!.completeError(e, s);
      _isFetching = false; // Ensure flag is reset on unrecoverable error
      rethrow;
    } finally {
      // Ensure fetching flag is reset regardless of outcome,
      // unless another fetch has started (which _isFetching and _fetchCompleter handle at start)
      // The primary reset of _isFetching after successful completion or error completion.
      _isFetching = false;
    }
  }

  /// Call this method at app startup to pre-load and cache data.
  static Future<void> primeCache() async {
    // debugPrint("OnDemand.primeCache: Attempting to prime cache...");
    try {
      // Call create without forcing refresh initially, so it uses cache if fresh
      await create(); 
      //debugPrint("OnDemand.primeCache: Cache priming attempt finished.");
    } catch (e) {
      // debugPrint("OnDemand.primeCache: Error during cache priming: $e. App will proceed with potentially stale or no cache.");
      // Errors during priming are logged but don't necessarily stop app startup.
      // The next call to create() will attempt to fetch again if needed.
    }
  }

  // return DateTime object from RSS date string
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

  // gets shows from RSS - this populates the 'shows' list for the current instance
  Future<void> _fetchShows() async {
    final List<String> streamUrls = await _Streams.getStreams();
    // Clear shows for the current instance being fetched
    // This method will be called on a new OnDemand._() instance each time a full fetch is needed
    List<PodcastShow> fetchedShows = []; // Use a temporary list

    for (var url in streamUrls) {
      try {
        // debugPrint("Fetching feed: $url");
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final feed = RssFeed.parse(response.body);

          final String showTitle = feed.title ?? 'Untitled Show';
          final String showDescription = _stripHtmlIfNeeded(feed.description ?? feed.itunes?.summary);
          // show picture falls back to MTR logo
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

            String rawDescription = item.content?.value ?? item.description ?? item.itunes?.summary ?? '';
            String cleanedDescription = _stripHtmlIfNeeded(rawDescription);

            currentShowEpisodes.add(Episode(
              guid: item.guid ?? 'no_guid_${item.title}_${DateTime.now().millisecondsSinceEpoch}',
              podcastName: showTitle,
              podcastImageUrl: showImageUrl,
              episodeSpecificImageUrl: item.itunes?.image?.href,
              episodeName: item.title ?? 'Untitled Episode',
              episodeDescription: cleanedDescription,
              episodeStreamUrl: item.enclosure?.url ?? '',
              episodeDateForDisplay: episodeDisplayDate,
              episodeDateForSorting: episodeSortDate,
              duration: formatDuration(item.itunes?.duration),
            ));
          }

          currentShowEpisodes.sort((a, b) {
            if (a.episodeDateForSorting == null && b.episodeDateForSorting == null) return 0;
            if (a.episodeDateForSorting == null) return 1;
            if (b.episodeDateForSorting == null) return -1;
            return b.episodeDateForSorting!.compareTo(a.episodeDateForSorting!);
          });

          // Add to the temporary list for this fetch operation
          fetchedShows.add(PodcastShow(
            title: showTitle,
            description: showDescription,
            imageUrl: showImageUrl,
            publishDate: channelPubDateString,
            sortablePublishDate: channelSortablePubDate,
            episodes: currentShowEpisodes,
            feedUrl: url,
          ));
        } else {
          // debugPrint('Failed to load RSS feed ($url): ${response.statusCode}');
        }
      } catch (e/*, s*/) {
        // debugPrint('Error processing RSS feed ($url): $e\n$s');
      }
    }

    fetchedShows.sort((a, b) {
      if (a.sortablePublishDate == null && b.sortablePublishDate == null) {
        return a.title.compareTo(b.title);
      }
      if (a.sortablePublishDate == null) return 1;
      if (b.sortablePublishDate == null) return -1;
      return b.sortablePublishDate!.compareTo(a.sortablePublishDate!);
    });
    
    // Assign the fetched shows to the instance's shows list
    shows = fetchedShows;
    // debugPrint("Fetched and processed ${shows.length} shows for the current instance.");
  }
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

One last thing to consider -- since we are fetching the RSS URLS and then the feeds themselves, the fetch is a bit slower.
To mitigate this, the getStreams could (and maybe should) run as soon as the app opens, and then cache the URL's
*/
class _Streams {
  //static const String feedsUrl = 'https://raw.githubusercontent.com/CivicTechWR/MidtownRadioApp/master/assets/tempfeeds.txt';
  static const String feedsUrl = 'https://raw.githubusercontent.com/david-harmes/Midtown-Radio-RSS/main/feeds.txt';
  
  static const List<String> _fallback = [
    'https://feeds.transistor.fm/midtown-radio',
    'https://feeds.transistor.fm/on-the-scene',
    'https://feeds.transistor.fm/makings-of-a-scene',
    'https://feeds.transistor.fm/midtown-conversations'
  ];

  static Future<List<String>> getStreams() async {
    try {
      // debugPrint("Fetching remote RSS feed URLs from $feedsUrl...");
      final resp = await http.get(Uri.parse(feedsUrl));
      if (resp.statusCode == 200) {
        final List<String> remote = resp.body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.startsWith('http'))
          .toList();
      // debugPrint("Done fetching remote");

        if (remote.isNotEmpty) {
            final remoteSet = Set<String>.from(remote);
            final mergedStreams = List<String>.from(remote);
            for (var fallbackUrl in _fallback) {
                if (!remoteSet.contains(fallbackUrl)) {
                    mergedStreams.add(fallbackUrl);
                }
            }
            return mergedStreams;
        } else {
            // debugPrint("Remote feed URL list was empty. Using fallback: ${_fallback.length} URLs.");
            return _fallback;
        }
      } else {
        // debugPrint('Failed to fetch remote feed URLs (Code: ${resp.statusCode}). Using fallback.');
        return _fallback;
      }
    } catch (e) {
      // debugPrint('Error fetching remote feed URLs: $e. Using fallback.');
      return _fallback;
    }
  }
}
