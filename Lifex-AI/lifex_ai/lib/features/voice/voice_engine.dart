/// =============================================================
/// Lifex-AI — وحدة الصوت والذكاء اللغوي
/// الملف: voice_engine.dart
/// المسار: lib/features/voice/voice_engine.dart
/// الوصف: المحرك المركزي الموجّه لكل وحدة الصوت — يوزّع المهام بين تحويل
/// الصوت لنص، النص لصوت، اكتشاف اللغة، والأوامر الصوتية، دون أن ينفذ
/// أياً منها بنفسه.
///
/// ⚠️ خصوصية إلزامية: أي تسجيل صوتي يتطلب إذن الميكروفون صراحة من
/// المستخدم (runtime permission) مع شرح واضح للسبب قبل الطلب. لا يُخزَّن
/// أو يُرسل أي مقطع صوتي لأي خادم دون موافقة صريحة ومنفصلة عن إذن النظام.
/// =============================================================
library lifex_ai.features.voice.voice_engine;

import '../../core/error_handler.dart';

/// حالة تشغيل محرك الصوت العامة.
enum VoiceEngineState { idle, listening, processing, speaking, error }

/// نتيجة عامة موحّدة لأي عملية صوتية.
class VoiceOperationResult {
  final bool success;
  final String? textResult;
  final String? errorMessageAr;

  const VoiceOperationResult.success({this.textResult})
      : success = true,
        errorMessageAr = null;

  const VoiceOperationResult.failure(this.errorMessageAr)
      : success = false,
        textResult = null;
}

/// توقيع دالة الاستماع لتغيّر حالة محرك الصوت (لتحديث الواجهة).
typedef VoiceStateListener = void Function(VoiceEngineState state);

/// المحرك المركزي لوحدة الصوت. لا يحتوي منطق تحويل فعلي؛ يُدير الحالة
/// العامة ويوجّه الطلبات للمحركات الفرعية المسجَّلة فيه.
class VoiceEngine {
  VoiceEngine._internal();
  static final VoiceEngine instance = VoiceEngine._internal();

  VoiceEngineState _state = VoiceEngineState.idle;
  final List<VoiceStateListener> _listeners = [];
  String? partialTranscript;
  String? activeLocaleId;
  String lastSignalAr = 'الصوت في وضع الانتظار';
  int speechEpoch = 0;
  int _listenEpoch = 0;

  /// دوال منفَّذة من المحركات الفرعية (تُسجَّل عند التهيئة عبر
  /// voice_command_engine أو غيره) لتنفيذ العمليات الفعلية.
  Future<VoiceOperationResult> Function()? _startListeningImpl;
  Future<void> Function()? _stopListeningImpl;
  Future<void> Function()? _stopSpeakingImpl;
  Future<VoiceOperationResult> Function(String text)? _speakImpl;

  VoiceEngineState get state => _state;

  void addStateListener(VoiceStateListener listener) =>
      _listeners.add(listener);
  void removeStateListener(VoiceStateListener listener) =>
      _listeners.remove(listener);

  void _setState(VoiceEngineState newState) {
    _state = newState;
    _notify();
  }

  void _notify() {
    for (final listener in List<VoiceStateListener>.from(_listeners)) {
      listener(_state);
    }
  }

  void signalAr(String message) {
    lastSignalAr = message;
    _notify();
  }

  void reportPartial(String text) {
    partialTranscript = text;
    if (text.trim().isNotEmpty) {
      lastSignalAr = 'أسمعك: $text';
    }
    _notify();
  }

  /// ربط التنفيذ الفعلي للاستماع (يُستدعى من speech_to_text_processor.dart).
  void bindListeningImplementation(
    Future<VoiceOperationResult> Function() implementation,
  ) {
    _startListeningImpl = implementation;
  }

  /// ربط التنفيذ الفعلي لإيقاف الاستماع.
  void bindStopListeningImplementation(
    Future<void> Function() implementation,
  ) {
    _stopListeningImpl = implementation;
  }

  void bindStopSpeakingImplementation(Future<void> Function() implementation) {
    _stopSpeakingImpl = implementation;
  }

  /// ربط التنفيذ الفعلي للنطق (يُستدعى من text_to_speech_manager.dart).
  void bindSpeakImplementation(
    Future<VoiceOperationResult> Function(String text) implementation,
  ) {
    _speakImpl = implementation;
  }

  /// الميكروفون بدأ فعلاً. لا تُعرض حالة الاستماع قبل هذه الإشارة.
  void noteCaptureStarted() {
    if (_state == VoiceEngineState.processing ||
        _state == VoiceEngineState.idle) {
      signalAr('الميكروفون يستقبل الكلام.');
      _setState(VoiceEngineState.listening);
    }
  }

  Future<VoiceOperationResult>? _listenFlight;

  /// بدء الاستماع لصوت المستخدم وتحويله لنص.
  /// جلسة واحدة في كل وقت: الطلب الثاني يُرفض حتى تنتهي الأولى.
  Future<VoiceOperationResult> startListening() async {
    if (_listenFlight != null) {
      signalAr('جلسة الاستماع السابقة لم تنته.');
      return const VoiceOperationResult.failure(
        'جلسة الاستماع السابقة لم تنته بعد.',
      );
    }
    final flight = _listenOnce();
    _listenFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_listenFlight, flight)) _listenFlight = null;
    }
  }

  /// يوقف الجلسة العالقة ثم يفتح جلسة جديدة. للبحث الصوتي والأوامر المتكررة.
  Future<VoiceOperationResult> listenFresh() async {
    if (_listenFlight != null ||
        _state == VoiceEngineState.listening ||
        _state == VoiceEngineState.processing) {
      await stopListening();
    }
    return startListening();
  }

  Future<VoiceOperationResult> _listenOnce() async {
    final epoch = _listenEpoch;
    if (_startListeningImpl == null) {
      ErrorHandler.instance.report(
        'VOICE_LISTEN_NOT_BOUND',
        'لم يتم ربط منفّذ الاستماع الصوتي بعد.',
        sourceModule: 'voice_engine',
        severity: ErrorSeverity.warning,
      );
      signalAr('التعرّف الصوتي غير مربوط.');
      return const VoiceOperationResult.failure(
        'ميزة التعرّف الصوتي غير جاهزة حالياً.',
      );
    }

    await _stopSpeakingImpl?.call();
    if (epoch != _listenEpoch) {
      return const VoiceOperationResult.failure('أُوقفت الجلسة السابقة.');
    }
    partialTranscript = null;
    signalAr('أجهّز التعرف على الكلام.');
    _setState(VoiceEngineState.processing);
    try {
      final result = await _startListeningImpl!();
      if (epoch != _listenEpoch) return result;
      signalAr(result.success
          ? 'وصل كلامك.'
          : (result.errorMessageAr ?? 'تعذّر الاستماع.'));
      _setState(
          result.success ? VoiceEngineState.idle : VoiceEngineState.error);
      return result;
    } catch (e, stackTrace) {
      if (epoch != _listenEpoch) {
        return const VoiceOperationResult.failure('أُوقفت الجلسة السابقة.');
      }
      signalAr('تعذّر تشغيل الميكروفون.');
      _setState(VoiceEngineState.error);
      ErrorHandler.instance.report(
        'VOICE_LISTEN_FAILED',
        'فشل تشغيل الاستماع الصوتي.',
        sourceModule: 'voice_engine',
        exception: e,
        stackTrace: stackTrace,
      );
      return const VoiceOperationResult.failure('حدث خطأ أثناء الاستماع.');
    }
  }

  Future<void> stopListening() async {
    _listenEpoch++;
    await _stopListeningImpl?.call();
    _listenFlight = null;
    _setState(VoiceEngineState.idle);
  }

  /// يقطع النطق فقط إذا كان المحرك يقرأ. التنقل الصامت لا يغيّر الإشارة.
  Future<void> interruptIfSpeaking() async {
    if (_state != VoiceEngineState.speaking) return;
    await stopSpeaking();
  }

  /// يقطع النطق الجاري. يزيد [speechEpoch] حتى يتجاهل المتصل نتيجة النطق القديمة.
  Future<void> stopSpeaking() async {
    speechEpoch++;
    await _stopSpeakingImpl?.call();
    signalAr('أوقفت القراءة.');
    _setState(VoiceEngineState.idle);
  }

  /// نطق نص معيّن بصوت مسموع (Text-to-Speech).
  Future<VoiceOperationResult> speak(String text) async {
    if (_speakImpl == null) {
      ErrorHandler.instance.report(
        'VOICE_SPEAK_NOT_BOUND',
        'لم يتم ربط منفّذ النطق الصوتي بعد.',
        sourceModule: 'voice_engine',
        severity: ErrorSeverity.warning,
      );
      signalAr('النطق غير مربوط.');
      return const VoiceOperationResult.failure(
        'ميزة القراءة الصوتية غير جاهزة حالياً.',
      );
    }

    final epoch = ++speechEpoch;
    signalAr('أردّ بالصوت الآن.');
    _setState(VoiceEngineState.speaking);
    final result = await _speakImpl!(text);
    if (epoch != speechEpoch) {
      return VoiceOperationResult.success(textResult: text);
    }
    signalAr(result.success
        ? 'انتهى الرد الصوتي.'
        : (result.errorMessageAr ?? 'تعذّر النطق.'));
    _setState(VoiceEngineState.idle);
    return result;
  }
}
