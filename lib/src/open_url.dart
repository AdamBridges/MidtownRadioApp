import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/main.dart';

final Uri _homepage = Uri.parse('https://www.midtownradio.ca/');
final Uri _contacts = Uri.parse('https://www.midtownradio.ca/copy-of-pop-out-player-1');

Future<void> openUrl(bool launchContacts) async {
  final Uri url = launchContacts ? _contacts : _homepage;
  
  // updated -- before, if user quit browser while loading, launchURL returns false and this would cause an error
  // now it should inly throw an error if theres an error
  try {
    if (!await launchUrl(url)) {
      mainScaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Could not open the link.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  } catch (e) {
    mainScaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('There was an error opening the link. Check internet connection.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}
