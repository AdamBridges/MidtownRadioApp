import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/layout/app_bar.dart'; // Assuming MainAppBar is your AppBar
import 'package:ctwr_midtown_radio_app/src/listen_live/view.dart';
import 'package:ctwr_midtown_radio_app/src/on_demand/view.dart';
import 'package:ctwr_midtown_radio_app/src/layout/drawer.dart';
import 'dart:math';
import '../settings/controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
  });

  static const routeName = '/';
  final SettingsController controller;


  @override
  Widget build(BuildContext context) {

    // the following are calculations to expand tabs and potentially put text on 2 or 3 rows if text is larger 
    // so that information is not lost if user needs larger text
    // for the "listen live" and "on demand" tabs
    final TextScaler textScaler = MediaQuery.of(context).textScaler;
    final double screenWidth = MediaQuery.of(context).size.width;
    const double baseTabFontSize = 18.0;
    
    int tabTextMaxLines = 1;
    final double currentTextScaleFactor = textScaler.scale(1); 

    // put the text on more lines if needed
    if (currentTextScaleFactor > 2.0) {
      tabTextMaxLines = 3;
    } else if (currentTextScaleFactor > 1.5) {
      tabTextMaxLines = 2;
    }

    final TextStyle tabLabelStyle = TextStyle(
      fontSize: baseTabFontSize,
      fontWeight: FontWeight.w900,
    );

    // Use TextPainter to get the height of a SINGLE line of scaled text
    final TextPainter singleLineTextPainter = TextPainter(
      text: TextSpan(text: "X", style: tabLabelStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    
    final double singleLineHeight = singleLineTextPainter.height;

    // Calculate total text height based on dynamic maxLines and single line height
    double calculatedTextHeight = singleLineHeight * tabTextMaxLines;
    
    // Add some inter-line spacing if maxLines > 1. TextPainter's height for multiple lines already includes this.
    if (tabTextMaxLines > 1) {
        calculatedTextHeight += (tabTextMaxLines - 1) * (singleLineHeight * 0.2);
    }

    const double tabVerticalPadding = 16.0;
    // tppable area must have height of at least 48
    double dynamicTabBarHeight = max(48, calculatedTextHeight + tabVerticalPadding);

    // debugPrint("Height: ${dynamicTabBarHeight}");

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: MainAppBar(),
        drawer: MainAppDrawer(
          themeMode: controller.themeMode,
          onThemeChanged: (newThemeMode) {
            controller.updateThemeMode(newThemeMode);
          },
        ),
        body: Column(
          children: [
            Container(
              height: dynamicTabBarHeight,
              alignment: Alignment.topCenter,
              color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  TabBar(
                    textScaler: textScaler,
                    labelColor: (Theme.of(context).brightness == Brightness.dark) 
                                ? const Color.fromRGBO(23, 204, 204, 1) 
                                : const Color(0xff00989d),
                    indicatorColor: (Theme.of(context).brightness == Brightness.dark) 
                                    ? Colors.white 
                                    : Colors.black,
                    labelStyle: tabLabelStyle,
                    tabs: [
                      Tab(
                        height: dynamicTabBarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            "LISTEN LIVE",
                            textAlign: TextAlign.center,
                            maxLines: tabTextMaxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Tab(
                        height: dynamicTabBarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            "ON DEMAND",
                            maxLines: tabTextMaxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // simple red dot for style
                  Positioned(
                    top: dynamicTabBarHeight / 2 - 5,
                    left: screenWidth / 2 - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFf05959),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListenLivePage(),
                  OnDemandPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
