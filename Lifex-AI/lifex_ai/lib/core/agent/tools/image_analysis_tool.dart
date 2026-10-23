/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: image_analysis_tool.dart
/// المسار: lib/core/agent/tools/image_analysis_tool.dart
/// الوصف: غلاف رقيق حول SmartVisionEngine الموجود فعلاً في
/// features/vision/smart_vision_engine.dart. يمرر نوع مهمة الرؤية
/// (جلد/جرح/دواء/شاشة جهاز) القادم في الوسائط، ولا يحتوي أي منطق
/// تحليل بصري بذاته.
/// =============================================================
library;

import '../../../features/vision/smart_vision_engine.dart';
import '../agent_context.dart';
import '../agent_permissions.dart';
import 'agent_tool.dart';

class ImageAnalysisTool implements AgentTool {
  ImageAnalysisTool({required SmartVisionEngine visionEngine})
      : _visionEngine = visionEngine;

  final SmartVisionEngine _visionEngine;

  static const Map<String, VisionTaskType> _taskTypeByName = {
    'skinAnalysis': VisionTaskType.skinAnalysis,
    'woundAnalysis': VisionTaskType.woundAnalysis,
    'medicineLabelRead': VisionTaskType.medicineLabelRead,
    'medicalDeviceScreenRead': VisionTaskType.medicalDeviceScreenRead,
    'medicalTextOcr': VisionTaskType.medicalTextOcr,
  };

  @override
  String get name => 'image_analysis';

  @override
  String get descriptionAr =>
      'تحليل صورة طبية (جلد/جرح/دواء/شاشة جهاز) عبر محرك الرؤية الذكية.';

  @override
  Map<String, String> get inputSchema => const {
        'imageBytes': 'List<int> — بايتات الصورة',
        'visionTaskType':
            'String — أحد: skinAnalysis, woundAnalysis, medicineLabelRead, medicalDeviceScreenRead, medicalTextOcr',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {AgentPermission.readUserImages},
        riskLevel: AgentActionRiskLevel.medium,
      );

  @override
  bool validate(Map<String, dynamic> arguments) {
    final bytes = arguments['imageBytes'];
    final taskType = arguments['visionTaskType'];
    return bytes is List &&
        bytes.isNotEmpty &&
        taskType is String &&
        _taskTypeByName.containsKey(taskType);
  }

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    final imageBytes = (arguments['imageBytes'] as List).cast<int>();
    final taskType = _taskTypeByName[arguments['visionTaskType'] as String]!;

    final result = await _visionEngine.process(
      type: taskType,
      imageBytes: imageBytes,
    );

    if (!result.success) {
      return AgentToolExecutionResult.failure(result.extractedSummaryAr);
    }

    return AgentToolExecutionResult.success({
      'dataType': 'image_analysis',
      'summaryAr': result.extractedSummaryAr,
      'structuredData': result.structuredData,
      'confidence': _mapNumericConfidence(result.confidence),
      'disclaimerAr': result.disclaimer,
    });
  }

  String _mapNumericConfidence(double value) {
    if (value >= 0.75) return 'high';
    if (value >= 0.4) return 'medium';
    if (value > 0.0) return 'low';
    return 'unknown';
  }
}
