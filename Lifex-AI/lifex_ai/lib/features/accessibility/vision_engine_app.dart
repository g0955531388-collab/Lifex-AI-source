/// فتح تطبيق المحرك على الهاتف. لا متصفح، ولا ادّعاء أن الفيديو اتصل.
library lifex_ai.features.accessibility.vision_engine_app;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VisionEngineApp {
  const VisionEngineApp({
    required this.id,
    required this.nameAr,
    required this.packages,
    required this.viewUrl,
  });

  final String id;
  final String nameAr;
  final List<String> packages;

  /// يُمرَّر إلى التطبيق نفسه فقط. المتصفح لا يستلمه.
  final String viewUrl;
}

class VisionEngines {
  const VisionEngines._();

  static const gemini = VisionEngineApp(
    id: 'gemini',
    nameAr: 'جيميني',
    packages: ['com.google.android.apps.bard'],
    viewUrl: 'https://gemini.google.com/live',
  );

  static const copilot = VisionEngineApp(
    id: 'copilot',
    nameAr: 'كوبايلوت',
    packages: ['com.microsoft.copilot'],
    viewUrl: 'https://copilot.microsoft.com/',
  );

  static const chatgpt = VisionEngineApp(
    id: 'chatgpt',
    nameAr: 'شات جي بي تي',
    packages: ['com.openai.chatgpt'],
    viewUrl: 'https://chatgpt.com/',
  );

  static const claude = VisionEngineApp(
    id: 'claude',
    nameAr: 'كلود',
    packages: ['com.anthropic.claude'],
    viewUrl: 'https://claude.ai/new',
  );

  static const lens = VisionEngineApp(
    id: 'lens',
    nameAr: 'عدسة Google',
    packages: [
      'com.google.ar.lens',
      'com.google.android.googlequicksearchbox',
    ],
    viewUrl: 'google://lens',
  );

  static const all = [gemini, copilot, chatgpt, claude, lens];

  static VisionEngineApp byId(String id) {
    for (final engine in all) {
      if (engine.id == id) return engine;
    }
    return gemini;
  }
}

enum DirectGeminiRoute { local, external, internal }

/// إنترنت مع حزمة جيميني مثبتة: التطبيق الخارجي بعد تحرير الكاميرا.
/// إنترنت بلا حزمة: البث الداخلي والكاميرا تبقى. بلا إنترنت: الوصف المحلي.
DirectGeminiRoute directGeminiRoute({
  required bool online,
  required bool packageInstalled,
}) {
  if (!online) return DirectGeminiRoute.local;
  if (packageInstalled) return DirectGeminiRoute.external;
  return DirectGeminiRoute.internal;
}

class VisionAppOpen {
  const VisionAppOpen({required this.code, required this.spokenAr});

  /// view أو app أو missing أو unsupported.
  final String code;
  final String spokenAr;
}

class VisionAppDesk {
  const VisionAppDesk({this.opener});

  final Future<String> Function(List<String> packages, String viewUrl)? opener;

  Future<VisionAppOpen> open(VisionEngineApp engine) async {
    final open = opener ?? VisionAppChannel.open;
    var raw = 'missing';
    try {
      raw = await open(engine.packages, engine.viewUrl);
    } catch (_) {
      raw = 'missing';
    }
    final code = _code(raw);
    return VisionAppOpen(code: code, spokenAr: speech(engine, code));
  }

  static String _code(String raw) {
    if (raw.startsWith('view')) return 'view';
    if (raw.startsWith('app')) return 'app';
    if (raw == 'unsupported') return 'unsupported';
    return 'missing';
  }

  static String speech(VisionEngineApp engine, String code) {
    if (engine.id == 'lens') return _lensSpeech(code);
    switch (code) {
      case 'view':
        return 'فُتح تطبيق ${engine.nameAr} على مدخله الداخلي، وليس على موقع. '
            'كاميرته واتصال الفيديو إن ظهرا فهما داخل التطبيق نفسه. '
            'لا يُشترط مفتاح داخل Lifex. Lifex لم ينقل البث ولم يؤكد اتصال فيديو.';
      case 'app':
        return 'فُتح تطبيق ${engine.nameAr} على صفحته الأولى. '
            'لم أجد أمراً عاماً يفتح كاميرته مباشرة، فلم يُفتح موقع. '
            'Lifex لم ينقل البث.';
      case 'unsupported':
        return 'فتح تطبيق ${engine.nameAr} يتم على هاتف أندرويد. لم يُفتح موقع.';
      default:
        return 'تطبيق ${engine.nameAr} غير مثبت على هذا الهاتف. لم يُفتح موقع.';
    }
  }

  static String _lensSpeech(String code) {
    switch (code) {
      case 'view':
        return 'فُتح Google Lens داخل تطبيقه، وليس على موقع. '
            'الشرح الذي يظهر هناك من عدسة Google نفسها. '
            'Lifex لم ينقل صورة الكاميرا. هذا ليس تشخيصاً ولا قياس مسافة.';
      case 'app':
        return 'فُتح تطبيق عدسة Google على صفحته الأولى، وليس على موقع. '
            'Lifex لم ينقل صورة الكاميرا. هذا ليس تشخيصاً ولا قياس مسافة.';
      case 'unsupported':
        return 'فتح عدسة Google يتم على هاتف أندرويد. لم يُفتح موقع.';
      default:
        return 'تطبيق عدسة Google غير مثبت على هذا الهاتف. لم يُفتح موقع.';
    }
  }
}

class VisionAppChannel {
  const VisionAppChannel._();

  static const channel = MethodChannel('lifex_ai/vision_app');

  static Future<bool> installed(List<String> packages) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final value = await channel.invokeMethod<bool>('installed', {
        'packages': packages,
      });
      return value == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> open(List<String> packages, String viewUrl) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'unsupported';
    }
    final value = await channel.invokeMethod<String>('open', {
      'packages': packages,
      'viewUrl': viewUrl,
    });
    return value ?? 'missing';
  }
}
