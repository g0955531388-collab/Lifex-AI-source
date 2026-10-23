/// =============================================================
/// Lifex-AI — اتصال
/// الملف: link_sighting.dart
/// ظهور الجهاز على أي قناة ليس اتصالاً ولا تفويضاً ولا تحكماً.
/// يسري على الشبكة والسلك والبلوتوث والواي فاي وبقية الأنواع.
/// =============================================================
library lifex_ai.core.connectivity.link_sighting;

import 'connection_type.dart';

class LinkSighting {
  const LinkSighting({
    required this.link,
    required this.deviceId,
    this.label = '',
  });

  final ConnectionType link;
  final String deviceId;
  final String label;

  bool get connected => false;
  bool get authenticated => false;
  bool get authorized => false;
  bool get controlable => false;
  bool get readingIsMeasurement => false;
}

class LinkSightingLedger {
  final _items = <String, LinkSighting>{};

  static const appliesToEveryLink = true;

  /// ظهور جهاز موثوق سابقاً لا يفتح جلسة.
  static const autoConnectOnSightingAllowed = false;

  /// البحث عن سواقة لا يحمّل ملفاً ولا يشغّل كوداً وصل من الشبكة.
  static const remoteDriverDownloadAllowed = false;
  static const dynamicDriverLoadAllowed = false;

  /// يبدأ البحث بتسجيل المعرّف. الظهور يبقى بلا جلسة وبلا تنفيذ أمر.
  LinkSighting startDriverQuery(ConnectionType link, String deviceIdentifier) {
    return note(link, deviceIdentifier.trim(), label: 'driver-query');
  }

  LinkSighting note(ConnectionType link, String deviceId, {String label = ''}) {
    final sighting = LinkSighting(
      link: link,
      deviceId: deviceId,
      label: label,
    );
    _items['${link.name}:$deviceId'] = sighting;
    return sighting;
  }

  LinkSighting? find(ConnectionType link, String deviceId) =>
      _items['${link.name}:$deviceId'];

  List<LinkSighting> get all => List.unmodifiable(_items.values);

  /// يُسجَّل الظهور فقط. المعرّف الموثوق لا يُربط تلقائياً.
  List<LinkSighting> noteTrustedCandidates({
    required ConnectionType link,
    required Iterable<String> seenIds,
    required Iterable<String> trustedIds,
  }) {
    final trusted = trustedIds.toSet();
    return [
      for (final id in seenIds)
        if (trusted.contains(id)) note(link, id, label: 'trusted-candidate'),
    ];
  }
}
