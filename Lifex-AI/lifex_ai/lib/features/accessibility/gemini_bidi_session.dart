/// جلسة Gemini Live عبر WebSocket. الصورة لا تغادر قبل setupComplete.
library lifex_ai.features.accessibility.gemini_bidi_session;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/app_config.dart';

const geminiLiveModelFallback = 'models/gemini-3.8-live';

const geminiLiveInstructionAr =
    'تم فتح الاتصال الحي مع كاميرا Lifex-AI. '
    'هذا توجيه داخلي ولا يُعرض على الشاشة. '
    'أنت المساعد البصري لمستخدم كفيف، ومهمتك توجيه مستخدم كفيف. '
    'أخبره لحظياً وبشكل مستمر بما تشاهد الكاميرا، بجمل عربية قصيرة، كلما وصل إطار الفيديو. '
    'لا تتوقف عن الشرح ما دامت الإطارات تصل. '
    'قدّم الطريق والرصيف والسيارات وإشارات المرور وكل ما يمكن أن يؤذيه قبل أي تفصيل آخر. '
    'جملتك الأولى يجب أن تكون حرفياً: أهلا بك انا مساعدك البصري في لايفيكس انا اسمع وأرى. '
    'لا تذكر مسافة بالأمتار ولا تقل إن الطريق آمن. '
    'لا تشخّص ولا تخترع اسماً أو جرعة. '
    'إذا لم تتضح الصورة فقل: لم أتمكن من تمييز المشهد بثقة.';

const geminiLiveInstructionEn =
    'A live camera connection inside Lifex-AI is open. '
    'This instruction stays off the screen. '
    'You are the visual assistant for a blind user. '
    'Guide the user with short sentences in the interface language, '
    'as each video frame arrives. Keep describing while frames arrive. '
    'Put the road, the sidewalk, cars, traffic lights, and anything that could cause harm before any other detail. '
    'Your first sentence must be exactly: Welcome. I am your visual assistant in Lifex. I hear and see. '
    'Do not state a distance in meters and do not say the way is safe. '
    'Do not diagnose and do not invent a name or a dose. '
    'If the picture is unclear, say you cannot identify the scene with confidence.';

String geminiLiveInstructionFor(AppLanguage language) =>
    language == AppLanguage.english
        ? geminiLiveInstructionEn
        : geminiLiveInstructionAr;

String geminiLiveKickoffFor(AppLanguage language) => language == AppLanguage.english
    ? 'The live connection is open. Say exactly: '
        'Welcome. I am your visual assistant in Lifex. I hear and see. '
        'Then guide the user from the camera. Keep describing what you see. '
        'Start with the road, the sidewalk, cars, traffic lights, and anything that could cause harm. '
        'Do not say the way is safe and do not give a distance.'
    : 'تم فتح الاتصال الحي. مهمتك توجيه المستخدم الكفيف. '
        'قل أولاً حرفياً: أهلا بك انا مساعدك البصري في لايفيكس انا اسمع وأرى. '
        'ثم أخبره لحظياً بما تشاهد الكاميرا بشكل مستمر ولا تتوقف. '
        'ابدأ بالطريق والرصيف والسيارات وإشارات المرور وما يمكن أن يؤذيه. '
        'لا تقل إن الطريق آمن ولا تعطِ قياساً للمسافة.';

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
  if (text.contains('انا اسمع وأرى') ||
      text.toLowerCase().contains('i hear and see')) {
    return text;
  }
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
  String? instruction,
}) {
  final spoken = instruction ??
      geminiLiveInstructionFor(AppConfig.instance.defaultLanguage);
  final name = model.startsWith('models/') ? model : 'models/$model';
  return {
    'setup': {
      'model': name,
      'generationConfig': {
        'responseModalities': ['TEXT'],
      },
      'systemInstruction': {
        'parts': [
          {'text': spoken},
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
              'text': geminiLiveKickoffFor(AppConfig.instance.defaultLanguage),
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

  /// نص المستخدم على الجلسة النصية نفسها. بلا موجة صوت خام.
  Future<bool> sendUserText(String text) async {
    final trimmed = text.trim();
    if (!isReady || trimmed.isEmpty) return false;
    try {
      _socket.add(jsonEncode({
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': trimmed},
              ],
            },
          ],
          'turnComplete': true,
        },
      }));
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
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
