import 'package:url_launcher/url_launcher.dart';

final Uri _homepage = Uri.parse('https://www.midtownradio.ca/');
final Uri _contacts = Uri.parse('https://www.midtownradio.ca/copy-of-pop-out-player-1');

Future<void> openUrl(bool launchContacts) async {
  final Uri url = launchContacts ? _contacts : _homepage;
  if (!await launchUrl(url)) {
    throw 'Could not launch $url';
  }
}
