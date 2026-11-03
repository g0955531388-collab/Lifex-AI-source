import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/features/accessibility/blind_volume_shortcut.dart';
import 'package:lifex_ai/features/accessibility/gemini_bidi_session.dart';
import 'package:lifex_ai/features/ai/ai_service_router.dart';
import 'package:lifex_ai/features/voice/hardware_cue_calibrator.dart';

void main() {
  test('نموذج live يُختار ونموذج النص لا يُعامل كجلسة حية', () {
    final chosen = chooseGeminiLiveModelName(const [
      {
        'name': 'models/gemini-2.0-flash',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-3.8-live',
        'supportedGenerationMethods': ['bidiGenerateContent'],
      },
    ]);
    expect(chosen, 'models/gemini-3.8-live');
    expect(
      chooseGeminiLiveModelName(const [
        {
          'name': 'models/gemini-2.5-flash-native-audio-preview-12-2025',
          'supportedGenerationMethods': ['bidiGenerateContent'],
        },
        {
          'name': 'models/gemini-3.8-live',
          'supportedGenerationMethods': ['bidiGenerateContent'],
        },
      ]),
      'models/gemini-3.8-live',
    );
    expect(
      chooseGeminiLiveModelName(const [
        {'name': 'models/gemini-2.0-flash'},
      ]),
      isNull,
    );
  });

  test('مفتاح قصير أو وهمي لا يفتح جلسة', () {
    expect(geminiCredentialUsable('placeholder-key-value-long'), isFalse);
    expect(geminiCredentialUsable('short'), isFalse);
    expect(geminiCredentialUsable('a-real-looking-token-value-32'), isTrue);
  });

  test('رسالة الخادم تُقرأ بلا اختراع مشهد', () {
    final setup = parseLiveServerMessage('{"setupComplete":{}}');
    expect(setup.setupComplete, isTrue);
    expect(setup.failed, isFalse);
    final text = parseLiveServerMessage(jsonEncode({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {'text': 'أمامك باب.'},
          ],
        },
      },
    }));
    expect(text.texts, ['أمامك باب.']);
    expect(parseLiveServerMessage('not-json').failed, isTrue);
    expect(guardGeminiSceneSpeech(''), isEmpty);
    expect(guardGeminiSceneSpeech('على بعد مترين'), contains('غير مقيسة'));
    expect(guardGeminiSceneSpeech('أمامك شخص'), contains('ليس ضماناً'));
    final audioOnly = parseLiveServerMessage(jsonEncode({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': 'AAAA'},
            },
          ],
        },
      },
    }));
    expect(audioOnly.audioPresent, isTrue);
    expect(audioOnly.texts, isEmpty);
    final setupMessage = geminiLiveSetupMessage(model: 'models/gemini-3.8-live');
    final generation = (setupMessage['setup'] as Map)['generationConfig'] as Map;
    expect(generation['responseModalities'], ['TEXT']);
    expect(generation['mediaResolution'], 'MEDIA_RESOLUTION_LOW');
    expect(geminiLiveInstructionAr, contains('يسار أو وسط أو يمين'));
    expect(geminiLiveInstructionEn, contains('left, center, or right'));
    expect(geminiLiveModelAfterRejection('models/gemini-3.8-live'),
        'models/gemini-2.5-flash-native-audio-preview-12-2025');
    expect(geminiReconnectAllowed(1), isTrue);
    expect(geminiReconnectAllowed(5), isFalse);
    expect(geminiReconnectDelay(1), const Duration(seconds: 1));
    expect(geminiReconnectDelay(5), const Duration(seconds: 16));
    expect(geminiReconnectDelay(6).inSeconds <= 30, isTrue);
    final rejected = parseLiveServerMessage(
      '{"error":{"code":1008,"message":"model rejected"}}',
    );
    expect(rejected.modelRejected, isTrue);
    expect(rejected.failed, isTrue);
    final away = parseLiveServerMessage('{"goAway":{"timeLeft":"10s"}}');
    expect(away.goAway, isTrue);
    expect(away.failed, isFalse);
    final kickoff = geminiLiveKickoffFor(AppLanguage.arabic);
    expect(kickoff.contains('متر'), isFalse);
    expect(kickoff.contains('آمن'), isTrue);
    expect(kickoff.contains('تم فتح الاتصال الحي'), isTrue);
    expect(kickoff.contains('بشكل مستمر'), isTrue);
    expect(kickoff.contains('لحظياً'), isTrue);
    expect(kickoff.contains('توجيه'), isTrue);
    expect(geminiLiveInstructionAr.contains('تم فتح الاتصال الحي'), isTrue);
    expect(geminiLiveInstructionAr.contains('بشكل مستمر'), isTrue);
    expect(geminiLiveInstructionAr.contains('لحظياً'), isTrue);
    expect(geminiLiveInstructionAr.contains('توجيه مستخدم كفيف'), isTrue);
    expect(
      geminiLiveInstructionAr.contains(
        'أهلا بك انا مساعدك البصري في لايفيكس انا اسمع وأرى',
      ),
      isTrue,
    );
    expect(geminiLiveInstructionAr.contains('إشارات المرور'), isTrue);
    expect(
      guardGeminiSceneSpeech(
        'أهلا بك انا مساعدك البصري في لايفيكس انا اسمع وأرى',
      ),
      'أهلا بك انا مساعدك البصري في لايفيكس انا اسمع وأرى',
    );
  });

  test('الإطار لا يغادر قبل اكتمال التهيئة', () async {
    final socket = _FakeSocket();
    final connector = _Connector(socket);
    final pending = GeminiBidiVisionSession.start(
      apiKey: 'a-real-looking-token-value-32',
      model: 'models/gemini-3.8-live',
      connector: connector,
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, isNotEmpty);
    final setup = jsonDecode(socket.sent.first) as Map;
    expect(setup['setup'], isA<Map>());
    expect(setup.containsKey('realtimeInput'), isFalse);
    socket.addIncoming('{"setupComplete":{}}');
    final session = await pending;
    expect(session, isNotNull);
    expect(session!.framesLeaveDevice, isTrue);
    final sent = await session.sendJpeg(Uint8List.fromList([1, 2, 3, 4]));
    expect(sent, isTrue);
    final video = jsonDecode(socket.sent.last) as Map;
    expect(video['realtimeInput'], isA<Map>());
    final next = session.spoken.first;
    socket.addIncoming(jsonEncode({
      'serverContent': {
        'outputTranscription': {'text': 'توجد سيارة.'},
      },
    }));
    final spoken = await next;
    expect(spoken, contains('سيارة'));
    expect(spoken, contains('ليس ضماناً'));
    await session.close();
    expect(session.framesLeaveDevice, isFalse);
    expect(await session.sendJpeg(Uint8List.fromList([9])), isFalse);
  });

  test('فشل التهيئة لا يرسل صورة', () async {
    final socket = _FakeSocket();
    final pending = GeminiBidiVisionSession.start(
      apiKey: 'a-real-looking-token-value-32',
      model: 'models/gemini-3.8-live',
      connector: _Connector(socket),
    );
    await Future<void>.delayed(Duration.zero);
    socket.addIncoming('{"error":{"message":"denied"}}');
    final session = await pending;
    expect(session, isNull);
    expect(
      socket.sent.where((line) => line.contains('realtimeInput')),
      isEmpty,
    );
  });

  test('رفض 1008 ينتقل إلى النموذج البديل بلا إطار مبكر', () async {
    final first = _FakeSocket();
    final second = _FakeSocket();
    var index = 0;
    final sockets = [first, second];
    final pending = GeminiBidiVisionSession.start(
      apiKey: 'a-real-looking-token-value-32',
      model: 'models/gemini-3.8-live',
      connector: _SequenceConnector(() => sockets[index++]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(first.sent, isNotEmpty);
    first.addIncoming('{"error":{"code":1008,"message":"rejected"}}');
    await Future<void>.delayed(Duration.zero);
    expect(second.sent, isNotEmpty);
    final setup = jsonDecode(second.sent.first) as Map;
    expect(
      (setup['setup'] as Map)['model'],
      contains('gemini-2.5-flash-native-audio-preview-12-2025'),
    );
    expect(
      first.sent.where((line) => line.contains('realtimeInput')),
      isEmpty,
    );
    expect(
      second.sent.where((line) => line.contains('realtimeInput')),
      isEmpty,
    );
    second.addIncoming('{"setupComplete":{}}');
    final session = await pending;
    expect(session, isNotNull);
    expect(session!.phase, GeminiFramePhase.streaming);
    await session.close();
    expect(session.phase, GeminiFramePhase.idle);
  });

  test('أربع ضغطات تشتعل والثالثة لا، والنافذة الأوسع لا تغيّر الافتراضي', () {
    final window = HardwareTapWindow(
      needed: BlindVolumeShortcut.taps,
      window: const Duration(milliseconds: BlindVolumeShortcut.windowMs),
    );
    final t0 = DateTime(2026, 10, 21, 23);
    expect(window.register(t0, matchingKind: true), isFalse);
    expect(
      window.register(t0.add(const Duration(milliseconds: 400)), matchingKind: true),
      isFalse,
    );
    expect(
      window.register(t0.add(const Duration(milliseconds: 800)), matchingKind: true),
      isFalse,
    );
    expect(
      window.register(t0.add(const Duration(milliseconds: 1200)), matchingKind: true),
      isTrue,
    );
    final slow = HardwareTapWindow(
      needed: 4,
      window: const Duration(milliseconds: 1600),
    );
    expect(slow.register(t0, matchingKind: true), isFalse);
    expect(
      slow.register(t0.add(const Duration(milliseconds: 2000)), matchingKind: true),
      isFalse,
    );
    expect(slow.register(t0, matchingKind: false), isFalse);
    final calibrator = HardwareCueCalibrator();
    expect(calibrator.tapCount, 2);
    expect(calibrator.windowMs, 480);
    expect(BlindVolumeShortcut.armed(accessModeEnabled: false, shortcutChosen: false), isFalse);
    expect(BlindVolumeShortcut.armed(accessModeEnabled: true, shortcutChosen: false), isTrue);
    expect(BlindVolumeShortcut.confirmationAr, contains('ليفكس'));
    expect(BlindVolumeShortcut.foregroundOnlyAr, contains('شاشة القفل'));
  });
}

class _FakeSocket implements LiveSocket {
  final _incoming = StreamController<String>();
  final sent = <String>[];

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void add(String text) => sent.add(text);

  void addIncoming(String text) => _incoming.add(text);

  @override
  Future<void> close() async {
    await _incoming.close();
  }
}

class _Connector implements LiveSocketConnector {
  _Connector(this.socket);
  final _FakeSocket socket;

  @override
  Future<LiveSocket> connect(Uri uri) async {
    expect(uri.queryParameters.containsKey('key'), isTrue);
    expect(uri.toString().contains('BidiGenerateContent'), isTrue);
    return socket;
  }
}

class _SequenceConnector implements LiveSocketConnector {
  _SequenceConnector(this._next);
  final LiveSocket Function() _next;

  @override
  Future<LiveSocket> connect(Uri uri) async {
    expect(uri.toString().contains('BidiGenerateContent'), isTrue);
    return _next();
  }
}
