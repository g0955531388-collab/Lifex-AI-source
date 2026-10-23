/// تحديث نماذج الرؤية. بلا بصمة أو بلا اختبار لا يُستبدل النموذج العامل.
library lifex_ai.features.accessibility.vision_model_update_desk;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum ModelUpdateOutcome {
  skippedAutoOff,
  noCandidate,
  refusedBadSource,
  refusedUnsigned,
  waitingForWifi,
  downloadFailed,
  hashMismatch,
  untestedHold,
  probeFailed,
  activated,
}

class ModelUpdateReport {
  const ModelUpdateReport({
    required this.outcome,
    required this.messageAr,
    this.activeVersion,
    this.previousVersion,
  });

  final ModelUpdateOutcome outcome;
  final String messageAr;
  final String? activeVersion;
  final String? previousVersion;
}

class VisionModelRelease {
  const VisionModelRelease({
    required this.id,
    required this.version,
    required this.source,
    required this.sha256Hex,
    required this.licenseAr,
  });

  final String id;
  final String version;
  final Uri source;
  final String sha256Hex;
  final String licenseAr;
}

typedef ModelBytesFetch = Future<Uint8List?> Function(Uri source);
typedef ModelProbe = Future<bool> Function(Uint8List bytes);

class VisionModelUpdateDesk {
  VisionModelUpdateDesk({
    this.autoEnabled = true,
    this.wifiOnly = true,
    this.confirmedWifi,
    this.staged,
    this.fetch,
    this.probe,
  });

  static final VisionModelUpdateDesk instance = VisionModelUpdateDesk();

  static const autoKey = 'lifex_vision_model_auto';
  static const wifiKey = 'lifex_vision_model_wifi_only';

  bool autoEnabled;
  bool wifiOnly;

  /// true فقط عندما يُقاس أن الاتصال Wi-Fi. null تعني أن القياس غير متاح.
  bool? confirmedWifi;

  VisionModelRelease? staged;
  VisionModelRelease? active;
  VisionModelRelease? previous;
  ModelBytesFetch? fetch;
  ModelProbe? probe;

  void applyPrefs({bool? auto, bool? wifi}) {
    if (auto != null) autoEnabled = auto;
    if (wifi != null) wifiOnly = wifi;
  }

  Future<ModelUpdateReport> request({required bool manual}) async {
    if (!manual && !autoEnabled) {
      return const ModelUpdateReport(
        outcome: ModelUpdateOutcome.skippedAutoOff,
        messageAr: 'التحديث التلقائي متوقف بطلبك. لم أبدأ التنزيل.',
      );
    }
    final offer = staged;
    if (offer == null) {
      return ModelUpdateReport(
        outcome: ModelUpdateOutcome.noCandidate,
        messageAr:
            'لا توجد حزمة نموذج موقّعة في هذا البناء. نموذج ML Kit العامل بقي كما هو.',
        activeVersion: active?.version,
        previousVersion: previous?.version,
      );
    }
    if (offer.source.scheme != 'https' || offer.source.host.isEmpty) {
      return const ModelUpdateReport(
        outcome: ModelUpdateOutcome.refusedBadSource,
        messageAr: 'المصدر ليس https. لم يبدأ التنزيل.',
      );
    }
    final expected = offer.sha256Hex.trim().toLowerCase();
    if (expected.isEmpty) {
      return const ModelUpdateReport(
        outcome: ModelUpdateOutcome.refusedUnsigned,
        messageAr: 'الحزمة بلا بصمة sha256. لم تُفعَّل.',
      );
    }
    if (wifiOnly && confirmedWifi != true) {
      return const ModelUpdateReport(
        outcome: ModelUpdateOutcome.waitingForWifi,
        messageAr:
            'لم يُقاس أن الاتصال Wi-Fi. التنزيل لم يبدأ لأن النماذج الكبيرة تفضّل Wi-Fi.',
      );
    }
    final downloader = fetch;
    if (downloader == null) {
      return _kept(ModelUpdateOutcome.downloadFailed, 'تعذر تنزيل الحزمة. الإصدار المستقر بقي.');
    }
    final bytes = await downloader(offer.source);
    if (bytes == null || bytes.isEmpty) {
      return _kept(ModelUpdateOutcome.downloadFailed, 'تعذر تنزيل الحزمة. الإصدار المستقر بقي.');
    }
    final digest = await sha256Hex(bytes);
    if (digest != expected) {
      return _kept(
        ModelUpdateOutcome.hashMismatch,
        'البصمة لا تطابق الملف. حُذف المؤقت وبقي الإصدار المستقر.',
      );
    }
    final check = probe;
    if (check == null) {
      return _kept(
        ModelUpdateOutcome.untestedHold,
        'الحزمة طابقت البصمة، لكن لا اختبار دقة على هذا الجهاز. الإصدار المستقر بقي.',
      );
    }
    final passed = await check(bytes);
    if (!passed) {
      return _kept(
        ModelUpdateOutcome.probeFailed,
        'اختبار الحزمة فشل. لم تُستبدل النسخة العاملة.',
      );
    }
    if (active != null && active!.version != offer.version) {
      previous = active;
    }
    active = offer;
    return ModelUpdateReport(
      outcome: ModelUpdateOutcome.activated,
      messageAr: 'فُعّلت الحزمة ${offer.version}. النسخة السابقة محفوظة للرجوع.',
      activeVersion: active?.version,
      previousVersion: previous?.version,
    );
  }

  ModelUpdateReport _kept(ModelUpdateOutcome outcome, String messageAr) {
    return ModelUpdateReport(
      outcome: outcome,
      messageAr: messageAr,
      activeVersion: active?.version,
      previousVersion: previous?.version,
    );
  }

  static Future<String> sha256Hex(Uint8List bytes) async {
    final hash = await Sha256().hash(bytes);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
