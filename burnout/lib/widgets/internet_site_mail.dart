import 'package:url_launcher/url_launcher_string.dart';

class SiteMail {
  Future<void> siteEmail(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      //print('Não abriu $_url');
    }
  }
}
