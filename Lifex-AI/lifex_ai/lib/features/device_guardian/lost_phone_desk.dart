/// جاهزية العثور على الهاتف. الفحص الأخير ليس ضماناً إذا انطفأ الجهاز أو انقطعت التغطية.
library lifex_ai.features.device_guardian.lost_phone_desk;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class LostFix {
  const LostFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

class LostPhoneDesk {
  static const limitAr =
      'هذا الشرط يزيد فرص العثور على الهاتف، لكنه لا يضمن تحديد موقعه أو إرساله '
      'إذا كان الجهاز مطفأً، أو لا يملك تغطية، أو منع Android تشغيل الخدمة.';

  static const attemptLimit = 5;
  static const lockWindow = Duration(minutes: 15);

  bool consent = false;
  bool armed = false;
  bool sessionChecked = false;
  bool? lastMobileDataOn;
  bool? lastLocationOn;
  DateTime? lastCheckedAt;
  String? secretHash;
  int failures = 0;
  DateTime? lockedUntil;
  LostFix? pending;
  bool pendingUnsent = false;
  bool lostMode = false;
  String lastSendAr = 'لم تُحاول الإرسال.';
  final List<String> events = [];

  String readinessAr() {
    if (!sessionChecked) {
      return 'لم يُفحص الاتصال والموقع في هذه الجلسة. القيمة المحفوظة ليست جاهزية حالية. $limitAr';
    }
    if (!consent) {
      return 'العثور عن بُعد غير مفعّل لأن الموافقة لم تُعطَ. $limitAr';
    }
    if (lastMobileDataOn == null) {
      return 'لم يُقاس تبديل بيانات الهاتف. التفعيل غير مكتمل. $limitAr';
    }
    if (lastLocationOn != true || lastMobileDataOn != true) {
      return 'حماية العثور عن بُعد محدودة: البيانات أو الموقع ليسا مفعّلين الآن. '
          'لا أستطيع إجبار أندرويد على إعادة تشغيلهما. $limitAr';
    }
    if (!armed) {
      return 'المتطلبات لم تجتمع في آخر فحص. $limitAr';
    }
    return 'آخر فحص وجد بيانات الهاتف والموقع مفعّلين والموافقة مسجّلة. $limitAr';
  }

  String arm({
    required bool userConsent,
    required bool? mobileDataOn,
    required bool? locationOn,
    required DateTime now,
  }) {
    consent = userConsent;
    lastMobileDataOn = mobileDataOn;
    lastLocationOn = locationOn;
    lastCheckedAt = now;
    sessionChecked = true;
    armed = userConsent && mobileDataOn == true && locationOn == true;
    if (!userConsent) {
      return 'لن يُفعَّل العثور قبل موافقتك على بياناته وموقعه. $limitAr';
    }
    if (mobileDataOn == null) {
      return 'لم أستطع قياس بيانات الهاتف، لذلك لم يكتمل التفعيل. $limitAr';
    }
    if (!mobileDataOn || locationOn != true) {
      return 'التفعيل مرفوض حتى تُقاس بيانات الهاتف وخدمة الموقع وهما مفعّلتان. $limitAr';
    }
    return readinessAr();
  }

  String observe({
    required bool? mobileDataOn,
    required bool? locationOn,
    required DateTime now,
  }) {
    lastMobileDataOn = mobileDataOn;
    lastLocationOn = locationOn;
    lastCheckedAt = now;
    sessionChecked = true;
    if (mobileDataOn != true || locationOn != true) {
      armed = false;
    } else if (consent) {
      armed = true;
    }
    return readinessAr();
  }

  String nearbyReply({required bool earAvailable}) {
    if (!earAvailable) {
      return 'الاستماع غير متاح الآن. لن أعلن أن الهاتف يقول «أنا هنا» دائماً. $limitAr';
    }
    return 'أنا هنا. هذا الرد والشاشة مفتوحة وإذن الميكروفون ممنوح. $limitAr';
  }

  Future<void> rememberSecret(String secret) async {
    final trimmed = secret.trim();
    if (trimmed.isEmpty) {
      secretHash = null;
      return;
    }
    secretHash = await digest(trimmed);
  }

  Future<String> acceptRemote({
    required bool channelAuthenticated,
    required String secret,
    required LostFix? fresh,
    required bool canSend,
    required DateTime now,
    required Future<bool> Function(LostFix fix)? send,
  }) async {
    if (!channelAuthenticated) {
      lastSendAr = 'لا قناة مصادق عليها. الرسائل النصية لا تُقرأ تلقائياً. لم يُرسل موقع.';
      events.add(lastSendAr);
      return lastSendAr;
    }
    if (lockedUntil != null && now.isBefore(lockedUntil!)) {
      lastSendAr = 'المحاولات موقوفة بعد تكرار الرمز الخاطئ. لم يُرسل موقع.';
      events.add(lastSendAr);
      return lastSendAr;
    }
    if (lockedUntil != null && !now.isBefore(lockedUntil!)) {
      lockedUntil = null;
      failures = 0;
    }
    final offered = await digest(secret.trim());
    if (secretHash == null || offered != secretHash) {
      failures += 1;
      if (failures >= attemptLimit) {
        lockedUntil = now.add(lockWindow);
      }
      lastSendAr = 'الرمز غير مقبول. لم يُرسل موقع.';
      events.add(lastSendAr);
      return lastSendAr;
    }
    failures = 0;
    lockedUntil = null;
    if (fresh != null) pending = fresh;
    if (pending == null) {
      lastSendAr = 'قُبل الرمز ولا توجد نقطة موقع لإرسالها.';
      events.add(lastSendAr);
      return lastSendAr;
    }
    return _dispatch(canSend: canSend, send: send);
  }

  Future<String> onPathChanged({
    required bool hadMobilePath,
    required bool onWifi,
    required bool simEventKnown,
    required bool simRemoved,
    required bool canSend,
    required Future<bool> Function(LostFix fix)? send,
  }) async {
    if (!simEventKnown) {
      events.add('لم يُرصد حدث الشريحة على هذا الجهاز.');
    } else if (simRemoved) {
      events.add('رُصد غياب الشريحة من القراءة المتاحة.');
    }
    if (hadMobilePath || !onWifi || pending == null) {
      return events.last;
    }
    return _dispatch(canSend: canSend, send: send);
  }

  Future<String> retryPending({
    required bool canSend,
    required Future<bool> Function(LostFix fix)? send,
  }) {
    return _dispatch(canSend: canSend, send: send);
  }

  String enterLostMode() {
    lostMode = true;
    return 'وضع الفقدان يطلب الهدوء وإعادة محاولة الإرسال. '
        'لا أقدر على إجبار البيانات أو الموقع أو كتم الصوت أو إطفاء الشاشة، '
        'ولن أقطع الشبكة قبل محاولة موثقة. $limitAr';
  }

  Map<String, Object?> toMap() {
    return {
      'consent': consent,
      'armed': armed,
      'pinHash': secretHash,
      'failures': failures,
      'lockedUntil': lockedUntil?.toIso8601String(),
      'lostMode': lostMode,
      'pendingUnsent': pendingUnsent,
      'lastSendAr': lastSendAr,
      'lastCheckedAt': lastCheckedAt?.toIso8601String(),
    };
  }

  void restore(Map<dynamic, dynamic> raw) {
    consent = raw['consent'] == true;
    armed = false;
    sessionChecked = false;
    secretHash = raw['pinHash']?.toString();
    failures = raw['failures'] is int ? raw['failures'] as int : 0;
    final lock = raw['lockedUntil']?.toString();
    lockedUntil = lock == null ? null : DateTime.tryParse(lock);
    lostMode = raw['lostMode'] == true;
    pendingUnsent = raw['pendingUnsent'] == true;
    lastSendAr = raw['lastSendAr']?.toString() ?? lastSendAr;
    final checked = raw['lastCheckedAt']?.toString();
    lastCheckedAt = checked == null ? null : DateTime.tryParse(checked);
  }

  Future<String> _dispatch({
    required bool canSend,
    required Future<bool> Function(LostFix fix)? send,
  }) async {
    final fix = pending;
    if (fix == null) {
      lastSendAr = 'لا نقطة محفوظة لإعادة الإرسال.';
      events.add(lastSendAr);
      return lastSendAr;
    }
    if (!canSend || send == null) {
      pendingUnsent = true;
      lastSendAr = 'تعذر الإرسال. النقطة محفوظة بوقتها ودقتها ولم يُعلَن نجاح.';
      events.add(lastSendAr);
      return lastSendAr;
    }
    final ok = await send(fix);
    pendingUnsent = !ok;
    lastSendAr = ok
        ? 'أُرسلت النقطة الملتقطة عند ${fix.capturedAt.toIso8601String()} بدقة ${fix.accuracyMeters} متراً.'
        : 'أعادت القناة فشلاً. النقطة ما زالت بانتظار محاولة أخرى.';
    events.add(lastSendAr);
    return lastSendAr;
  }

  static Future<String> digest(String secret) async {
    final hash = await Sha256().hash(utf8.encode(secret));
    return hash.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
