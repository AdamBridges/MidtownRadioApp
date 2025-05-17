import 'package:flutter/material.dart';

import '../../widgets/animatedToggle.dart';
import '../settings/controller.dart';

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
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
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
              ],
              onChanged: (newTheme) {
                if (newTheme != null) {
                  onThemeChanged(newTheme);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}