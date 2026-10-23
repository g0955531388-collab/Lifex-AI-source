/// جلسة Gemini Live عبر WebSocket. الصورة لا تغادر قبل setupComplete.
library lifex_ai.features.accessibility.gemini_bidi_session;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const geminiLiveModelFallback = 'models/gemini-3.8-live';

const geminiLiveInstructionAr =
    'تم فتح الاتصال الحي مع كاميرا Lifex-AI. '
    'مهمتك الآن توجيه مستخدم كفيف. أخبره لحظياً وبشكل مستمر بما تشاهد الكاميرا، '
    'بجمل عربية قصيرة، كلما وصل إطار. '
    'لا تتوقف عن الشرح ما دامت الإطارات تصل. '
    'لا تذكر مسافة بالأمتار ولا تقل إن الطريق آمن. '
    'لا تشخّص ولا تخترع اسماً أو جرعة. '
    'إذا لم تتضح الصورة فقل: لم أتمكن من تمييز المشهد بثقة.';

bool geminiCredentialUsable(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 20) return false;
  final lower = trimmed.toLowerCase();
  return !lower.contains('placeholder') &&
      !lower.contains('your_api') &&
      !lower.contains('changeme');
}

String guardGeminiSceneSpeech(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text.startsWith('__')) return '';
  var spoken = 'وصف Gemini الحي: $text';
  final lower = text.toLowerCase();
  if (text.contains('متر') ||
      text.contains('على بعد') ||
      lower.contains('meter')) {
    spoken = '$spoken المسافة غير مقيسة.';
  }
  if (!spoken.contains('ليس ضماناً')) {
    spoken = '$spoken هذا وصف مساعد وليس ضماناً لخلو الطريق.';
  }
  return spoken;
}

class LiveServerEvent {
  const LiveServerEvent({
    required this.setupComplete,
    required this.failed,
    required this.texts,
    this.audioPresent = false,
  });

  final bool setupComplete;
  final bool failed;
  final List<String> texts;

  /// صوت خام من النموذج. لا يُشغَّل لأن المسافة والأمان لا يُفلتران من الموجة.
  final bool audioPresent;
}

LiveServerEvent parseLiveServerMessage(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const LiveServerEvent(
        setupComplete: false,
        failed: true,
        texts: [],
      );
    }
    if (decoded['error'] != null) {
      return const LiveServerEvent(
        setupComplete: false,
        failed: true,
        texts: [],
      );
    }
    if (decoded.containsKey('setupComplete')) {
      return const LiveServerEvent(
        setupComplete: true,
        failed: false,
        texts: [],
      );
    }
    final server = decoded['serverContent'];
    if (server is! Map) {
      return const LiveServerEvent(
        setupComplete: false,
        failed: false,
        texts: [],
      );
    }
    final texts = <String>[];
    var audioPresent = false;
    final turn = server['modelTurn'];
    if (turn is Map) {
      final parts = turn['parts'];
      if (parts is List) {
        for (final part in parts) {
          if (part is! Map) continue;
          if (part['text'] is String) {
            final text = (part['text'] as String).trim();
            if (text.isNotEmpty) texts.add(text);
          }
          final inline = part['inlineData'] ?? part['inline_data'];
          if (inline is Map && inline['data'] != null) {
            audioPresent = true;
          }
        }
      }
    }
    final transcript = server['outputTranscription'];
    if (transcript is Map && transcript['text'] is String) {
      final text = (transcript['text'] as String).trim();
      if (text.isNotEmpty) texts.add(text);
    }
    return LiveServerEvent(
      setupComplete: false,
      failed: false,
      texts: texts,
      audioPresent: audioPresent,
    );
  } catch (_) {
    return const LiveServerEvent(
      setupComplete: false,
      failed: true,
      texts: [],
    );
  }
}

Map<String, Object?> geminiLiveSetupMessage({
  required String model,
  String instruction = geminiLiveInstructionAr,
}) {
  final name = model.startsWith('models/') ? model : 'models/$model';
  return {
    'setup': {
      'model': name,
      'generationConfig': {
        'responseModalities': ['TEXT'],
      },
      'systemInstruction': {
        'parts': [
          {'text': instruction},
        ],
      },
      'outputAudioTranscription': <String, Object?>{},
    },
  };
}

Map<String, Object?> geminiLiveKickoffMessage() {
  return {
    'clientContent': {
      'turns': [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'تم فتح الاتصال الحي. مهمتك توجيه المستخدم الكفيف. '
                  'أخبره لحظياً بما تشاهد الكاميرا بشكل مستمر ولا تتوقف. '
                  'لا تقل إن الطريق آمن ولا تعطِ قياساً للمسافة.',
            },
          ],
        },
      ],
      'turnComplete': true,
    },
  };
}
Map<String, Object?> geminiLiveVideoMessage(String base64Jpeg) {
  return {
    'realtimeInput': {
      'video': {
        'mimeType': 'image/jpeg',
        'data': base64Jpeg,
      },
    },
  };
}

abstract class LiveSocket {
  Stream<String> get messages;
  void add(String text);
  Future<void> close();
}

abstract class LiveSocketConnector {
  Future<LiveSocket> connect(Uri uri);
}

class IoLiveSocket implements LiveSocket {
  IoLiveSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages => _socket.map((event) => '$event');

  @override
  void add(String text) => _socket.add(text);

  @override
  Future<void> close() => _socket.close();
}

class IoLiveSocketConnector implements LiveSocketConnector {
  const IoLiveSocketConnector();

  @override
  Future<LiveSocket> connect(Uri uri) async {
    final socket = await WebSocket.connect(uri.toString());
    return IoLiveSocket(socket);
  }
}

class GeminiBidiVisionSession {
  GeminiBidiVisionSession._(this._socket);

  final LiveSocket _socket;
  final StreamController<String> _spoken = StreamController<String>.broadcast();
  StreamSubscription<String>? _subscription;
  var _ready = false;
  var _closed = false;
  DateTime? _lastSent;
  String _lastSpoken = '';

  bool get isReady => _ready && !_closed;

  /// تبقى كاذبة حتى تكتمل تهيئة الجلسة.
  bool get framesLeaveDevice => isReady;

  Stream<String> get spoken => _spoken.stream;

  static Future<GeminiBidiVisionSession?> start({
    required String apiKey,
    required String model,
    LiveSocketConnector connector = const IoLiveSocketConnector(),
  }) async {
    if (!geminiCredentialUsable(apiKey)) return null;
    final uri = Uri(
      scheme: 'wss',
      host: 'generativelanguage.googleapis.com',
      path:
          '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
      queryParameters: {'key': apiKey},
    );
    LiveSocket socket;
    try {
      socket = await connector.connect(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
    final session = GeminiBidiVisionSession._(socket);
    final ready = session._waitUntilReady();
    try {
      socket.add(jsonEncode(geminiLiveSetupMessage(model: model)));
    } catch (_) {
      await session.close();
      return null;
    }
    final opened = await ready;
    if (!opened) {
      await session.close();
      return null;
    }
    return session;
  }

  Future<bool> _waitUntilReady() {
    final done = Completer<bool>();
    _subscription = _socket.messages.listen(
      (raw) {
        final event = parseLiveServerMessage(raw);
        if (event.failed) {
          _ready = false;
          if (!done.isCompleted) done.complete(false);
          return;
        }
        if (event.setupComplete && !done.isCompleted) {
          _ready = true;
          done.complete(true);
          try {
            _socket.add(jsonEncode(geminiLiveKickoffMessage()));
          } catch (_) {
            _ready = false;
            if (!done.isCompleted) done.complete(false);
          }
        }
        if (event.audioPresent && event.texts.isEmpty) {
          const held =
              'وصل صوت من Gemini بلا نص يمكن فحصه. لم يُشغَّل حتى لا تُقال مسافة أو أمان غير مقيس.';
          if (held != _lastSpoken && !_spoken.isClosed) {
            _lastSpoken = held;
            _spoken.add(held);
          }
        }
        for (final text in event.texts) {
          final spoken = guardGeminiSceneSpeech(text);
          if (spoken.isEmpty || spoken == _lastSpoken) continue;
          _lastSpoken = spoken;
          if (!_spoken.isClosed) _spoken.add(spoken);
        }
      },
      onError: (_) {
        _ready = false;
        if (!done.isCompleted) done.complete(false);
      },
      onDone: () {
        _ready = false;
        if (!done.isCompleted) done.complete(false);
      },
    );
    return done.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
  }

  /// إطار واحد كحد أقصى كل ثانية. الإطار الفارغ لا يُرسل.
  Future<bool> sendJpeg(Uint8List jpeg) async {
    if (!isReady || jpeg.isEmpty || jpeg.length > 1200000) return false;
    final now = DateTime.now();
    if (_lastSent != null &&
        now.difference(_lastSent!) < const Duration(seconds: 1)) {
      return true;
    }
    _lastSent = now;
    try {
      _socket.add(jsonEncode(geminiLiveVideoMessage(base64Encode(jpeg))));
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
  }

  Future<void> close() async {
    _ready = false;
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    try {
      await _socket.close();
    } catch (_) {}
    if (!_spoken.isClosed) await _spoken.close();
  }
}
