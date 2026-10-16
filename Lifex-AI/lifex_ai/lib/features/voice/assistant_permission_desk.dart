/// =============================================================
/// Lifex-AI — إذن النظام منفصل عن موافقة التطبيق.
/// لا يُطلب الإذن مرة ثانية ما دام ممنوحاً، ولا تُتجاوز حالة الرفض الدائم.
/// =============================================================
library lifex_ai.features.voice.assistant_permission_desk;

enum OsPermissionKind { granted, denied, blocked }

class AssistantPermissionDesk {
  const AssistantPermissionDesk();

  static const revokedAr =
      'الإذن مسحوب من إعدادات النظام. افتح إعدادات التطبيق، ثم الأذونات، '
      'وأعد تفعيل الميكروفون أو الكاميرا. موافقة Lifex داخل التطبيق لا تغني عن إذن أندرويد.';

  static const deniedAr =
      'لم يُمنح الإذن. يمكن السماح به من النافذة، أو لاحقاً من إعدادات التطبيق ثم الأذونات.';

  static String? lastExplanationAr;

  static OsPermissionKind classify({
    required bool granted,
    required bool blocked,
  }) {
    if (granted) return OsPermissionKind.granted;
    if (blocked) return OsPermissionKind.blocked;
    return OsPermissionKind.denied;
  }

  bool shouldAskOperatingSystem(OsPermissionKind kind) =>
      kind == OsPermissionKind.denied;

  Future<bool> ensure({
    required Future<OsPermissionKind> Function() read,
    required Future<OsPermissionKind> Function() request,
  }) async {
    final now = await read();
    if (now == OsPermissionKind.granted) {
      lastExplanationAr = null;
      return true;
    }
    if (!shouldAskOperatingSystem(now)) {
      lastExplanationAr = revokedAr;
      return false;
    }
    final asked = await request();
    if (asked == OsPermissionKind.granted) {
      lastExplanationAr = null;
      return true;
    }
    lastExplanationAr =
        asked == OsPermissionKind.blocked ? revokedAr : deniedAr;
    return false;
  }
}
