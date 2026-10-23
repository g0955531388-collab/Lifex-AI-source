/// فتح رابط رسمي خارج التطبيق. الفشل لا يُعرض كنتيجة داخلية.
library lifex_ai.features.search.external_link_desk;

import 'package:url_launcher/url_launcher.dart';

class ExternalLinkResult {
  const ExternalLinkResult({
    required this.opened,
    required this.uri,
    required this.messageAr,
  });

  final bool opened;
  final Uri uri;
  final String messageAr;
}

class ExternalLinkDesk {
  const ExternalLinkDesk({this.opener});

  final Future<bool> Function(Uri uri)? opener;

  Future<ExternalLinkResult> open(Uri uri) async {
    final open = opener ?? _pluginOpen;
    try {
      final opened = await open(uri);
      return ExternalLinkResult(
        opened: opened,
        uri: uri,
        messageAr: opened
            ? 'غادرت إلى ${uri.host}. ما يظهر هناك ليس نتيجة داخل Lifex-AI.'
            : 'تعذّر فتح ${uri.host}. لم تُعرض صفحة خارجية داخل التطبيق.',
      );
    } catch (_) {
      return ExternalLinkResult(
        opened: false,
        uri: uri,
        messageAr: 'تعذّر فتح ${uri.host}. تحقق من المتصفح أو الاتصال.',
      );
    }
  }

  static Future<bool> _pluginOpen(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
