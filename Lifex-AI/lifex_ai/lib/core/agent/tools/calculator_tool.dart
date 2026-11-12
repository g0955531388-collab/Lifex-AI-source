/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: calculator_tool.dart
/// المسار: lib/core/agent/tools/calculator_tool.dart
/// الوصف: أداة حسابية بسيطة وآمنة (عمليات ثابتة محددة سلفاً فقط —
/// وليس مفسّر تعابير حر) يستخدمها الوكيل لعمليات مثل حساب BMI أو
/// تحويل وحدات شائعة في السياق الطبي. لا تُنفَّذ أي شيفرة حرة (بند 29:
/// عدم السماح للوكيل بتنفيذ كود Dart عشوائي).
/// =============================================================
library;

import '../agent_context.dart';
import '../agent_permissions.dart';
import 'agent_tool.dart';

enum SupportedCalculation { bmi, celsiusToFahrenheit, fahrenheitToCelsius }

class CalculatorTool implements AgentTool {
  const CalculatorTool();

  static const Map<String, SupportedCalculation> _byName = {
    'bmi': SupportedCalculation.bmi,
    'celsiusToFahrenheit': SupportedCalculation.celsiusToFahrenheit,
    'fahrenheitToCelsius': SupportedCalculation.fahrenheitToCelsius,
  };

  @override
  String get name => 'calculator';

  @override
  String get descriptionAr =>
      'إجراء حسابات ثابتة محددة سلفاً (مثل BMI أو تحويل وحدات الحرارة).';

  @override
  Map<String, String> get inputSchema => const {
        'operation': 'String — أحد: bmi, celsiusToFahrenheit, fahrenheitToCelsius',
        'values': 'Map<String, num> — القيم المطلوبة حسب العملية',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {},
        riskLevel: AgentActionRiskLevel.low,
      );

  @override
  bool validate(Map<String, dynamic> arguments) {
    final operation = arguments['operation'] as String?;
    return operation != null && _byName.containsKey(operation);
  }

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    final operation = _byName[arguments['operation'] as String]!;
    final values = (arguments['values'] as Map?)?.cast<String, dynamic>() ?? {};

    try {
      switch (operation) {
        case SupportedCalculation.bmi:
          final weightKg = (values['weightKg'] as num).toDouble();
          final heightM = (values['heightM'] as num).toDouble();
          if (heightM <= 0) {
            return const AgentToolExecutionResult.failure(
                'قيمة الطول غير صالحة لحساب مؤشر كتلة الجسم.');
          }
          final bmi = weightKg / (heightM * heightM);
          return AgentToolExecutionResult.success({
            'dataType': 'calculation_result',
            'operation': 'bmi',
            'result': bmi,
            'confidence': 'high',
          });

        case SupportedCalculation.celsiusToFahrenheit:
          final c = (values['celsius'] as num).toDouble();
          return AgentToolExecutionResult.success({
            'dataType': 'calculation_result',
            'operation': 'celsiusToFahrenheit',
            'result': (c * 9 / 5) + 32,
            'confidence': 'high',
          });

        case SupportedCalculation.fahrenheitToCelsius:
          final f = (values['fahrenheit'] as num).toDouble();
          return AgentToolExecutionResult.success({
            'dataType': 'calculation_result',
            'operation': 'fahrenheitToCelsius',
            'result': (f - 32) * 5 / 9,
            'confidence': 'high',
          });
      }
    } catch (_) {
      return const AgentToolExecutionResult.failure(
          'قيم مدخلة غير صالحة لإجراء هذا الحساب.');
    }
  }
}
