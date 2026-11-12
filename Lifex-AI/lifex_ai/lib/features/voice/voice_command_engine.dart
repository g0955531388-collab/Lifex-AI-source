/// =============================================================
/// Lifex-AI — وحدة الصوت والذكاء اللغوي
/// الملف: voice_command_engine.dart
/// المسار: lib/features/voice/voice_command_engine.dart
/// الوصف: محرك الأوامر الصوتية — يستقبل النص المُحوَّل من الصوت، يستخدم
/// command_parser.dart لتفسيره، وينفّذ الإجراء المطابق داخل التطبيق عبر
/// دوال مُسجَّلة مسبقاً (بدل ربط هذا الملف مباشرة بكل شاشة في النظام).
/// =============================================================

import '../../core/error_handler.dart';
import 'command_parser.dart';
import 'voice_engine.dart';

/// توقيع دالة تنفيذ أمر صوتي واحد.
typedef VoiceCommandAction = Future<void> Function(ParsedVoiceCommand command);

/// نتيجة تنفيذ أمر صوتي كامل (من الصوت وحتى تنفيذ الإجراء).
class VoiceCommandExecutionResult {
  final bool recognized;
  final bool executed;
  final String? feedbackMessageAr;

  const VoiceCommandExecutionResult({
    required this.recognized,
    required this.executed,
    this.feedbackMessageAr,
  });
}

/// محرك الأوامر الصوتية. تُسجَّل فيه الإجراءات المدعومة (مثل "افتح ملفي
/// الصحي" أو "اتصل بالطوارئ") من الشاشات/الوحدات المعنية عند التهيئة.
class VoiceCommandEngine {
  VoiceCommandEngine({required this.parser});

  final CommandParser parser;

  final Map<VoiceCommandIntent, VoiceCommandAction> _actions = {};

  /// تسجيل إجراء تنفيذي لنيّة أمر معيّنة.
  void registerAction(VoiceCommandIntent intent, VoiceCommandAction action) {
    _actions[intent] = action;
  }

  /// المسار الكامل: نص صوتي خام → تفسير → تنفيذ.
  Future<VoiceCommandExecutionResult> handleRawSpeechText(
    String rawText,
  ) async {
    final parsed = parser.parse(rawText);

    if (parsed.intent == VoiceCommandIntent.unknown) {
      return const VoiceCommandExecutionResult(
        recognized: false,
        executed: false,
        feedbackMessageAr:
            'لم أفهم الأمر بوضوح. حاول صياغته بشكل مختلف، مثل: "افتح ملفي الصحي".',
      );
    }

    final action = _actions[parsed.intent];
    if (action == null) {
      ErrorHandler.instance.report(
        'VOICE_COMMAND_NO_ACTION_REGISTERED',
        'تم تفسير الأمر (${parsed.intent.name}) لكن لا يوجد إجراء منفَّذ له.',
        sourceModule: 'voice_command_engine',
        severity: ErrorSeverity.warning,
      );
      return const VoiceCommandExecutionResult(
        recognized: true,
        executed: false,
        feedbackMessageAr: 'هذا الأمر غير متاح حالياً في هذا الجزء من التطبيق.',
      );
    }

    try {
      await action(parsed);
      return const VoiceCommandExecutionResult(
        recognized: true,
        executed: true,
      );
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'VOICE_COMMAND_EXECUTION_FAILED',
        'فشل تنفيذ الأمر الصوتي: ${parsed.intent.name}',
        sourceModule: 'voice_command_engine',
        exception: e,
        stackTrace: stackTrace,
      );
      return const VoiceCommandExecutionResult(
        recognized: true,
        executed: false,
        feedbackMessageAr: 'حدث خطأ أثناء تنفيذ الأمر. حاول مرة أخرى.',
      );
    }
  }

  /// دمج مباشر مع VoiceEngine: الاستماع ثم التفسير ثم التنفيذ في خطوة واحدة.
  Future<VoiceCommandExecutionResult> listenAndExecute(
    VoiceEngine voiceEngine,
  ) async {
    final listenResult = await voiceEngine.listenFresh();
    if (!listenResult.success || listenResult.textResult == null) {
      return VoiceCommandExecutionResult(
        recognized: false,
        executed: false,
        feedbackMessageAr:
            listenResult.errorMessageAr ?? 'تعذّر التعرّف على الصوت.',
      );
    }
    return handleRawSpeechText(listenResult.textResult!);
  }
}
