import 'package:ctwr_midtown_radio_app/src/open_url.dart';
import 'package:flutter/material.dart';

class MainAppDrawer extends StatelessWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;


  const MainAppDrawer({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {

        
    return LayoutBuilder(
      builder: (context, constraints) {

        final isNarrow = constraints.maxWidth < 360 || MediaQuery.of(context).textScaler.scale(1) > 1.5;

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo_main.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pushNamed(context, '/');
                },
              ),
              // I dont think we need settings now since we have theme here
              // ListTile(
              //   leading: const Icon(Icons.settings),
              //   title: const Text('Settings'),
              //   onTap: () {
              //     Navigator.pushNamed(context, '/settings');
              //   },
              // ),

              // if narrow or text is scaled large, the dropdown will go under instead of beside
              isNarrow 
                // stacked vertically, if space is tight
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text("Theme"),
                      leading: const Icon(Icons.color_lens),

                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DropdownButton<ThemeMode>(
                        isExpanded: true,
                          value: themeMode,
                          underline: SizedBox(), // Removes the underline for cleaner look
                          items: const [
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text('Light')
                              ),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text('Dark')
                              ),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text('System')
                              ),
                            ),
                          ],
                          onChanged: (newTheme) {
                            if (newTheme != null) {
                              onThemeChanged(newTheme);
                            }
                          },
                        ),
                    ),
                  ],
                )
                // standard display, side by side
                : ListTile(
                  leading: const Icon(Icons.color_lens),
                  title: const Text('Theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    underline: SizedBox(), // Removes the underline for cleaner look
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                    ],
                    onChanged: (newTheme) {
                      if (newTheme != null) {
                        onThemeChanged(newTheme);
                      }
                    },
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text("Our Site"),
                onTap: () {
                  openUrl(false);
                }
              )
            ],
          ),
        );
      }
    );
  }
}