import 'package:flutter/material.dart';

class MainAppDrawer extends StatelessWidget {
  const MainAppDrawer({
    super.key
  });

  @override
  Widget build(BuildContext context){
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              //color: Colors.black,
            ),
            child: Center(
              child: Image.asset('assets/images/logo_main.png',
                fit: BoxFit.cover,
                //height: 55,
              ),
              // child: Text(
              //   'Midtown Radio',
              //   style: TextStyle(
              //     color: (Theme.of(context).brightness == Brightness.dark) ? Color.fromRGBO(23, 204, 204, 1):Color(0xff00989d),
              //     fontSize: 24,
              //     fontWeight: FontWeight.w900
              //   ),
              // ),
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
        ],
      ),
    );
  }
}