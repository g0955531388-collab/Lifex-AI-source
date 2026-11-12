/// جلسة Gemini الحية عبر المحرك المثبت. الرد نص يُفحص قبل النطق.
/// المفتاح القصير أو انقطاع المقبس يرجّع الوصف إلى الكاميرا المحلية.
library lifex_ai.features.camera_ai.cloud.live_camera_provider;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../accessibility/gemini_bidi_session.dart';

enum LiveSessionState {
  idle,
  connecting,
  live,
  localFallback,
}

class CloudFrame {
  const CloudFrame({required this.jpegBase64, required this.timestampMs});

  final String jpegBase64;
  final int timestampMs;
}

typedef GeminiSessionStarter = Future<GeminiBidiVisionSession?> Function({
  required String apiKey,
  required String model,
});

abstract class LiveCameraProvider {
  Future<void> connect();
  Future<void> sendFrame(CloudFrame frame);
  Future<void> sendText(String userText);
  Stream<String> get utterances;
  LiveSessionState get state;
  Future<void> disconnect();
}

class GeminiLiveProvider implements LiveCameraProvider {
  GeminiLiveProvider({
    required this.profileId,
    required this.readApiKey,
    required this.announcer,
    this.model = geminiLiveModelFallback,
    GeminiSessionStarter? startSession,
  }) : _startSession = startSession ?? _openInstalledSession;

  static Future<GeminiBidiVisionSession?> _openInstalledSession({
    required String apiKey,
    required String model,
  }) {
    return GeminiBidiVisionSession.start(apiKey: apiKey, model: model);
  }

  final String profileId;
  final Future<String?> Function() readApiKey;
  final Future<void> Function(String phrase) announcer;
  final String model;
  final GeminiSessionStarter _startSession;

  final _utterances = StreamController<String>.broadcast();
  StreamSubscription<String>? _spoken;
  GeminiBidiVisionSession? _session;
  LiveSessionState _state = LiveSessionState.idle;

  @override
  LiveSessionState get state => _state;

  @override
  Stream<String> get utterances => _utterances.stream;

  @override
  Future<void> connect() async {
    if (_state == LiveSessionState.connecting || _state == LiveSessionState.live) {
      return;
    }
    _state = LiveSessionState.connecting;
    try {
      final apiKey = (await readApiKey())?.trim() ?? '';
      if (!geminiCredentialUsable(apiKey)) {
        _state = LiveSessionState.localFallback;
        return;
      }
      final session = await _startSession(apiKey: apiKey, model: model);
      if (session == null) {
        await _fallBack();
        return;
      }
      _session = session;
      _state = LiveSessionState.live;
      _spoken = session.spoken.listen(
        (phrase) {
          if (!_utterances.isClosed && phrase.trim().isNotEmpty) {
            _utterances.add(phrase);
          }
        },
        onError: (_) {
          unawaited(_fallBack());
        },
        onDone: () {
          unawaited(_fallBack());
        },
      );
    } catch (_) {
      await _fallBack();
    }
  }

  @override
  Future<void> sendFrame(CloudFrame frame) async {
    final session = _session;
    if (_state != LiveSessionState.live ||
        session == null ||
        frame.jpegBase64.isEmpty) {
      return;
    }
    try {
      final bytes = base64Decode(frame.jpegBase64);
      final sent = await session.sendJpeg(Uint8List.fromList(bytes));
      if (!sent && !session.isReady) await _fallBack();
    } catch (_) {
      await _fallBack();
    }
  }

  @override
  Future<void> sendText(String userText) async {
    final session = _session;
    if (_state != LiveSessionState.live || session == null) return;
    final sent = await session.sendUserText(userText);
    if (!sent && !session.isReady) await _fallBack();
  }

  Future<void> _fallBack() async {
    if (_state == LiveSessionState.localFallback) return;
    _state = LiveSessionState.localFallback;
    await _closeSession();
    try {
      await announcer(
        'انقطع الاتصال بالمحرك السحابي. سأعمل بالكاميرا المحلية حتى يعود الاتصال.',
      );
    } catch (_) {}
  }

  Future<void> _closeSession() async {
    await _spoken?.cancel();
    _spoken = null;
    final session = _session;
    _session = null;
    if (session != null) await session.close();
  }

  @override
  Future<void> disconnect() async {
    _state = LiveSessionState.idle;
    await _closeSession();
    if (!_utterances.isClosed) await _utterances.close();
  }
}
