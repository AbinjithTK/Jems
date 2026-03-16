import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Placeholder URLs — replace with your actual legal pages before release.
class JemsUrls {
  static const String privacyPolicy = 'https://jems.com/privacy';
  static const String termsOfService = 'https://jems.com/terms';
}

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $url')),
    );
  }
}
