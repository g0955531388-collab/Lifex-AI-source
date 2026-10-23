/// فحص وصول الإنترنت. الفشل يعني عدم الفتح، ولا يُختلق اتصال.
library lifex_ai.features.accessibility.internet_reachability;

import 'dart:io';

class InternetReachability {
  const InternetReachability({this.lookup});

  final Future<bool> Function()? lookup;

  Future<bool> get online async {
    final probe = lookup ?? _lookupDns;
    try {
      return await probe().timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _lookupDns() async {
    final hits = await InternetAddress.lookup('dns.google');
    return hits.isNotEmpty && hits.first.rawAddress.isNotEmpty;
  }
}
