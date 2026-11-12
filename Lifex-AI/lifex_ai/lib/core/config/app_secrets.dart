/// نقطة واحدة للاعتمادات والروابط. لا قيم سرية في هذا الملف.
/// الأولوية: assets/config/app_config.json ثم --dart-define ثم فراغ.
/// المفاتيح المسطحة في القالب والمفاتيح المتداخلة القديمة تُقرآن معاً.
library lifex_ai.core.config.app_secrets;

import 'dart:convert';

import 'package:flutter/services.dart';

class AppSecrets {
  AppSecrets._();

  static var _loaded = false;
  static Map<String, dynamic> _fileConfig = {};

  static const _stripeKey = String.fromEnvironment('LIFEX_STRIPE_KEY');
  static const _stripePublishable =
      String.fromEnvironment('LIFEX_STRIPE_PUBLISHABLE_KEY');
  static const _paypal = String.fromEnvironment('LIFEX_PAYPAL_CLIENT_ID');
  static const _backend = String.fromEnvironment('LIFEX_BACKEND_URL');
  static const _manifest = String.fromEnvironment('LIFEX_MEDICAL_MANIFEST_URL');
  static const _translationZip =
      String.fromEnvironment('LIFEX_GOOGLE_TRANSLATION_KEY');
  static const _translation =
      String.fromEnvironment('LIFEX_TRANSLATION_API_KEY');
  static const _vision = String.fromEnvironment('LIFEX_GOOGLE_VISION_KEY');
  static const _icd11Id = String.fromEnvironment('LIFEX_ICD11_CLIENT_ID');
  static const _icd11Secret =
      String.fromEnvironment('LIFEX_ICD11_CLIENT_SECRET');

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/config/app_config.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _fileConfig = decoded;
      }
    } catch (_) {
      _fileConfig = {};
    }
    _loaded = true;
  }

  static String get stripePublishableKey =>
      _resolve('stripe.publishableKey', _stripeKey, _stripePublishable);

  static String get paypalClientId =>
      _resolve('paypal.clientId', _paypal, '');

  static String get backendBaseUrl =>
      _resolve('backend.baseUrl', _backend, '');

  static String get medicalManifestUrl => _resolve(
        'backend.medicalManifestUrl',
        _manifest,
        '',
      );

  static String get googleTranslationApiKey =>
      _resolve('translation.googleApiKey', _translationZip, _translation);

  /// مفتاح Cloud Vision. الفارغ يبقي القراءة على الجهاز.
  static String get googleVisionApiKey =>
      _resolve('vision.googleApiKey', _vision, '');

  static String get icd11ClientId =>
      _resolve('terminology.icd11.clientId', _icd11Id, '');

  static String get icd11ClientSecret =>
      _resolve('terminology.icd11.clientSecret', _icd11Secret, '');

  /// وجود رابط بعد رفض المثال والعنصر النائب. ليس دليلاً على خادم منتج.
  static bool get hasRealBackend => backendBaseUrl.isNotEmpty;

  /// وجود مفتاح Stripe.publishable. ليس حركة أموال ولا إثبات تحصيل.
  static bool get hasRealPayments => stripePublishableKey.isNotEmpty;

  static void require(String value, String serviceName) {
    if (value.trim().isEmpty) {
      throw StateError(
        'خدمة $serviceName غير مفعّلة: الاعتمادات مفقودة.',
      );
    }
  }

  static const _aliases = <String, List<String>>{
    'backend.medicalManifestUrl': ['medical.manifestUrl'],
    'terminology.icd11.clientId': ['icd11.clientId'],
    'terminology.icd11.clientSecret': ['icd11.clientSecret'],
  };

  static String _resolve(String fileKey, String envA, String envB) {
    final fromFile = _clean(_fileValue(fileKey));
    if (fromFile.isNotEmpty) return fromFile;
    final first = _clean(envA);
    if (first.isNotEmpty) return first;
    return _clean(envB);
  }

  static String _fileValue(String fileKey) {
    final direct = _readPath(fileKey);
    if (direct.isNotEmpty) return direct;
    for (final alias in _aliases[fileKey] ?? const <String>[]) {
      final value = _readPath(alias);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _readPath(String path) {
    final direct = _fileConfig[path];
    if (direct is String) return direct;
    dynamic node = _fileConfig;
    for (final part in path.split('.')) {
      if (node is Map && node[part] != null) {
        node = node[part];
      } else {
        return '';
      }
    }
    return node is String ? node : '';
  }

  static String _clean(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (lower.contains('placeholder') || lower.contains('example.com')) {
      return '';
    }
    return trimmed;
  }
}
