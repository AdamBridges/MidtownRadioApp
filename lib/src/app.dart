import 'package:ctwr_midtown_radio_app/main.dart';
// import 'package:ctwr_midtown_radio_app/src/on_demand/episode_list.dart';
import 'package:ctwr_midtown_radio_app/src/settings/controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:ctwr_midtown_radio_app/src/media_player/widget.dart';
import 'package:ctwr_midtown_radio_app/src/settings/view.dart';
import 'package:ctwr_midtown_radio_app/src/error/view.dart';
import 'package:ctwr_midtown_radio_app/src/home/view.dart';
import 'package:ctwr_midtown_radio_app/src/listen_live/view.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/view.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:ctwr_midtown_radio_app/src/open_url.dart';

class MidtownRadioApp extends StatelessWidget {
  const MidtownRadioApp({
    super.key,
    required this.settingsController,
    required this.navigatorKey
  });

  final SettingsController settingsController;
  final GlobalKey<NavigatorState> navigatorKey;


  @override
  Widget build(BuildContext context) {
    return MidtownRadioStateful(
      settingsController: settingsController,
      navigatorKey: navigatorKey,
    );
  }
}

class MidtownRadioStateful extends StatefulWidget {
  const MidtownRadioStateful({
    super.key,
    required this.settingsController,
    required this.navigatorKey
  });

  final SettingsController settingsController;
  final GlobalKey<NavigatorState> navigatorKey;


  @override
  MidtownRadioState createState() => MidtownRadioState();
}

class MidtownRadioState extends State<MidtownRadioStateful> {
  final ValueNotifier<bool> isModalOpen = ValueNotifier<bool>(false);
  String? _lastError;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.settingsController,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp(
            // Debugger: true,
            debugShowCheckedModeBanner: false,
            navigatorKey: widget.navigatorKey,

            builder: (context, child) => Semantics(
              sortKey: const OrdinalSortKey(0),
              explicitChildNodes: true,
              child: Scaffold(
                  body: Semantics(
                    sortKey: const OrdinalSortKey(0),
                    child: child
                  ),
                  // Changed to nav bar so that body contents don't end up behind it
                  bottomNavigationBar: ValueListenableBuilder<bool>(
                  valueListenable: isModalOpen,
                  builder: (context, modalOpen, _) {
                    if (modalOpen) return const SizedBox.shrink();
                    return StreamBuilder<MediaItem?>(
                      stream: audioHandler.mediaItem,
                      builder: (context, mediaSnapshot) {
                        final mediaItem = mediaSnapshot.data;
                        return StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, stateSnapshot) {
                            final playbackState = stateSnapshot.data;
                            final processingState = playbackState?.processingState ??
                                AudioProcessingState.idle;
              
                            final showPlayer = mediaItem != null &&
                                processingState != AudioProcessingState.idle;
              
                            if (!showPlayer) return const SizedBox.shrink();
                            return Semantics(
                              button: true,
                              sortKey: OrdinalSortKey(1),
                              explicitChildNodes: true,
                              label: "Expand Fullscreen Player View",
                              child: PlayerWidget(
                                navigatorKey: widget.navigatorKey,
                                isModalOpen: isModalOpen,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            initialRoute: HomePage.routeName,

          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          supportedLocales: const [
            Locale('en', ''),
            Locale('fr', ''),
          ],

          onGenerateTitle: (BuildContext context) =>  AppLocalizations.of(context)!.appTitle,

          theme: ThemeData(),
          darkTheme: ThemeData.dark(),
          themeMode: widget.settingsController.themeMode,

          onGenerateRoute: (RouteSettings routeSettings) {
            try {
              switch (routeSettings.name) {
                case HomePage.routeName:
                  return MaterialPageRoute(builder: (_) => const HomePage());
                case ListenLivePage.routeName:
                  return MaterialPageRoute(builder: (_) => const ListenLivePage());
                case OnDemandPage.routeName:
                  return MaterialPageRoute(builder: (_) => const OnDemandPage());
                case SettingsPage.routeName:
                  return MaterialPageRoute(
                    builder: (_) => SettingsPage(controller: widget.settingsController),
                  );
                default:
                  // For unknown routes, pass the route name to ErrorPage
                  return MaterialPageRoute(
                    builder: (_) => ErrorPage(
                      error: 'Route not found: ${routeSettings.name}',
                      stackTrace: null,
                    ),
                  );
              }
            } catch (e, stack) {
              // Catch any errors during route generation
              return MaterialPageRoute(
                builder: (_) => ErrorPage(
                  error: 'Failed to load route: ${e.toString()}',
                  stackTrace: kDebugMode ? stack.toString() : null,
                ),
              );
            }
          },
        );
      }
      );
  }

  @override
  void initState() {
    super.initState();

    // catch errors - navigate to error page
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(error, stack);

      // this is important, returning true prevents dart from trying to handle the errors itself.
      // we want to handle them ourselves
      return true;
    };
  }

  void _handleError(dynamic error, StackTrace? stack) {
    // Avoid duplicate errors and error loops
    final errorStr = error.toString();
    if (_lastError == errorStr || !mounted) return;
    _lastError = errorStr;

    debugPrint('Error: $error\n$stack');
    
    WidgetsBinding.instance.addPostFrameCallback((_) async{
      await widget.navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ErrorPage(
            error: errorStr,
            stackTrace: kDebugMode ? stack.toString() : null,
          ),
        ),
      );
      _lastError = "";
    });
  }
}