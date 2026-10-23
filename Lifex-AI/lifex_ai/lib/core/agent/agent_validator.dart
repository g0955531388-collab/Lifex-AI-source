/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_validator.dart
/// المسار: lib/core/agent/agent_validator.dart
/// الوصف: طبقة التحقق بعد تنفيذ أي عملية مهمة (بند 18). تدعم Validators
/// متعددة حسب نوع البيانات (Strategy pattern)، وتفرض برمجياً القاعدة:
/// "لا يجوز تحويل ثقة منخفضة إلى نتيجة قطعية" (بند 17).
/// =============================================================
library;

import 'agent_confidence.dart';
import 'agent_observation.dart';

enum ValidationOutcome { valid, retry, replan, askUser }

class ValidationResult {
  const ValidationResult({
    required this.outcome,
    required this.reasonAr,
    this.adjustedConfidence,
  });

  final ValidationOutcome outcome;
  final String reasonAr;

  /// إن أراد الـ Validator تخفيض مستوى الثقة (وليس رفعه أبداً — الدمج
  /// يتم دائماً عبر AgentConfidence.combineWith، الذي يختار الأضعف).
  final AgentConfidence? adjustedConfidence;

  bool get isValid => outcome == ValidationOutcome.valid;
}

/// عقد أي مدقق مخصص لنوع بيانات معيّن (نتيجة OCR، نتيجة تحليل طبي،
/// نتيجة استرجاع معرفة...).
abstract class AgentValidatorStrategy {
  /// اسم فئة البيانات التي يتحقق منها هذا الـ Validator (يُطابق
  /// AgentObservation.data['dataType'] إن وُجد).
  String get dataType;

  ValidationResult validate(AgentObservation observation);
}

/// مدقق افتراضي عام: يفحص فقط أن الملاحظة نجحت وتحمل ثقة معروفة. أي
/// نوع بيانات لا يملك Validator مخصصاً يمر عبر هذا كحد أدنى آمن.
class DefaultAgentValidatorStrategy implements AgentValidatorStrategy {
  @override
  String get dataType => 'default';

  @override
  ValidationResult validate(AgentObservation observation) {
    if (!observation.success) {
      return const ValidationResult(
        outcome: ValidationOutcome.retry,
        reasonAr: 'فشلت العملية ولم تُرجع بيانات صالحة.',
      );
    }

    if (observation.confidence == AgentConfidence.unknown) {
      return const ValidationResult(
        outcome: ValidationOutcome.askUser,
        reasonAr: 'مستوى الثقة في النتيجة غير معروف — يفضَّل تأكيد المستخدم.',
      );
    }

    return const ValidationResult(
      outcome: ValidationOutcome.valid,
      reasonAr: 'النتيجة صالحة.',
    );
  }
}

class AgentValidator {
  AgentValidator({List<AgentValidatorStrategy>? strategies})
      : _strategies = {
          for (final s in strategies ?? const []) s.dataType: s,
        } {
    _strategies.putIfAbsent(
        'default', () => DefaultAgentValidatorStrategy());
  }

  final Map<String, AgentValidatorStrategy> _strategies;

  void register(AgentValidatorStrategy strategy) {
    _strategies[strategy.dataType] = strategy;
  }

  ValidationResult validate(AgentObservation observation) {
    final dataType = observation.data?['dataType'] as String? ?? 'default';
    final strategy = _strategies[dataType] ?? _strategies['default']!;
    return strategy.validate(observation);
  }
}
