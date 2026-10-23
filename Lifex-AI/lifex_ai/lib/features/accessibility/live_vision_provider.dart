/// مزودو الرؤية الحية. غياب الرمز أو الخادم يبقي الإرسال مغلقاً.
library lifex_ai.features.accessibility.live_vision_provider;

import 'dart:typed_data';

import 'vision_engine_app.dart';

enum LiveVisionPhase {
  unconfigured,
  awaitingConsent,
  ready,
  connected,
  sending,
  receiving,
  failed,
  unavailable,
  stopped,
}

class LiveVisionSession {
  const LiveVisionSession({
    required this.phase,
    required this.spokenAr,
    required this.framesLeaveDevice,
  });

  final LiveVisionPhase phase;
  final String spokenAr;
  final bool framesLeaveDevice;
}

/// عقد مزود رؤية. الكاميرا لا تعرف تفاصيل Gemini أو غيره.
abstract interface class LiveVisionProvider {
  String get nameAr;

  LiveVisionSession get session;

  Future<LiveVisionSession> open();

  Future<LiveVisionSession> sendFrame(Uint8List jpegBytes);

  Future<LiveVisionSession> close();
}

/// Gemini Live يحتاج رمزاً قصير العمر من خادم موثوق. لا مفتاح داخل التطبيق.
class GeminiLiveVisionProvider implements LiveVisionProvider {
  GeminiLiveVisionProvider({this.ephemeralTokenIssuerConfigured = false});

  /// هذا البناء بلا Firebase وبلا خادم غير example.com، فيبقى false.
  final bool ephemeralTokenIssuerConfigured;

  /// موافقة محددة على مغادرة الإطار للجهاز. الغياب يبقي الصورة محلية.
  bool frameLeaveConsent = false;

  void grantFrameLeaveConsent() => frameLeaveConsent = true;

  void revokeFrameLeaveConsent() => frameLeaveConsent = false;

  LiveVisionSession _session = const LiveVisionSession(
    phase: LiveVisionPhase.unconfigured,
    spokenAr:
        'Gemini Live غير مهيأ. لا يوجد خادم يصدر رمزاً قصير العمر، '
        'ولم يُوضع مفتاح داخل التطبيق. لم تُرسل صورة.',
    framesLeaveDevice: false,
  );

  @override
  String get nameAr => 'Gemini Live';

  @override
  LiveVisionSession get session => _session;

  @override
  Future<LiveVisionSession> open() async {
    if (!ephemeralTokenIssuerConfigured) {
      _session = const LiveVisionSession(
        phase: LiveVisionPhase.unconfigured,
        spokenAr:
            'جلسة Gemini Live لم تُفتح. ينقص رمز قصير العمر من خادم موثوق. '
            'الكاميرا المحلية مستمرة، ولم تغادر أي صورة الجهاز.',
        framesLeaveDevice: false,
      );
      return _session;
    }
    _session = const LiveVisionSession(
      phase: LiveVisionPhase.unavailable,
      spokenAr:
          'مُصدِر الرمز مذكور بلا عنوان اتصال مُختبر. الجلسة غير متاحة، '
          'ولم تُرسل صورة.',
      framesLeaveDevice: false,
    );
    return _session;
  }

  @override
  Future<LiveVisionSession> sendFrame(Uint8List jpegBytes) async {
    if (!frameLeaveConsent) {
      _session = const LiveVisionSession(
        phase: LiveVisionPhase.awaitingConsent,
        spokenAr:
            'الإطار لم يُرسل. مغادرة الصورة للجهاز تحتاج موافقة محددة. '
            'الوصف المحلي مستمر.',
        framesLeaveDevice: false,
      );
      return _session;
    }
    if (jpegBytes.isEmpty) {
      _session = const LiveVisionSession(
        phase: LiveVisionPhase.failed,
        spokenAr: 'لا إطار لإرساله. لا نتيجة تحليل.',
        framesLeaveDevice: false,
      );
      return _session;
    }
    if (_session.phase != LiveVisionPhase.connected &&
        _session.phase != LiveVisionPhase.receiving) {
      final held = _session.phase == LiveVisionPhase.failed ||
              _session.phase == LiveVisionPhase.unavailable
          ? _session.phase
          : LiveVisionPhase.unconfigured;
      _session = LiveVisionSession(
        phase: held,
        spokenAr: 'لا جلسة Gemini متصلة. الإطار لم يُرسل. لا نتيجة تحليل.',
        framesLeaveDevice: false,
      );
      return _session;
    }
    _session = const LiveVisionSession(
      phase: LiveVisionPhase.failed,
      spokenAr: 'الإرسال الحي غير مثبت في هذا البناء. الإطار بقي على الجهاز.',
      framesLeaveDevice: false,
    );
    return _session;
  }

  @override
  Future<LiveVisionSession> close() async {
    frameLeaveConsent = false;
    _session = const LiveVisionSession(
      phase: LiveVisionPhase.stopped,
      spokenAr: 'جلسة Gemini Live موقوفة. لا إرسال.',
      framesLeaveDevice: false,
    );
    return _session;
  }
}

/// فتح تطبيق المحرك. لا يُفتح متصفح.
class ExternalVisionHandoff {
  const ExternalVisionHandoff({this.desk = const VisionAppDesk()});

  final VisionAppDesk desk;

  Future<String> openEngine(String id) async {
    final opened = await desk.open(VisionEngines.byId(id));
    return opened.spokenAr;
  }

  Future<String> openGemini() => openEngine('gemini');

  Future<String> openCopilot() => openEngine('copilot');

  Future<String> openChatGpt() => openEngine('chatgpt');

  Future<String> openClaude() => openEngine('claude');

  Future<String> openLens() => openEngine('lens');
}
