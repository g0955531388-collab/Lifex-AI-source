/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: report_generator_tool.dart
/// المسار: lib/core/agent/tools/report_generator_tool.dart
/// الوصف: يجمع مخرجات الخطوات السابقة (نص مستخرج، نتائج معرفة، تحليل
/// صورة) في تقرير منظّم واحد — بدون أي استدعاء لمزوّد ذكاء اصطناعي
/// خارجي هنا؛ هذا تجميع وتنسيق بيانات فقط (deterministic)، وهذا
/// مقصود: يبقى التقرير قابلاً للتفسير الكامل ولا يعتمد على استقرار رد
/// نموذج خارجي حر الشكل.
/// =============================================================
library;

import '../agent_confidence.dart';
import '../agent_context.dart';
import '../agent_permissions.dart';
import 'agent_tool.dart';

class ReportGeneratorTool implements AgentTool {
  const ReportGeneratorTool();

  @override
  String get name => 'report_generator';

  @override
  String get descriptionAr => 'إنشاء تقرير منظّم من نتائج الخطوات السابقة.';

  @override
  Map<String, String> get inputSchema => const {
        'priorObservations': 'List<Map> — نتائج الخطوات السابقة الناجحة',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {AgentPermission.generateReport},
        riskLevel: AgentActionRiskLevel.low,
      );

  @override
  bool validate(Map<String, dynamic> arguments) => true;

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    final priorObservations =
        (arguments['priorObservations'] as List<dynamic>?) ?? const [];

    final sections = <Map<String, dynamic>>[];
    final sourceFiles = <String>{};
    AgentConfidence overallConfidence = AgentConfidence.high;

    for (final obs in priorObservations) {
      if (obs is! Map<String, dynamic>) continue;

      final dataType = obs['dataType'] as String?;
      final confidenceStr = obs['confidence'] as String?;
      overallConfidence = overallConfidence
          .combineWith(_parseConfidence(confidenceStr));

      switch (dataType) {
        case 'document_ocr':
          sections.add({
            'titleAr': 'نص المستند المستخرج',
            'contentAr': obs['extractedText'],
            'documentType': obs['documentType'],
          });
          break;
        case 'raw_ocr_text':
          sections.add({
            'titleAr': 'نص مستخرج',
            'contentAr': obs['extractedText'],
          });
          break;
        case 'image_analysis':
          sections.add({
            'titleAr': 'تحليل الصورة',
            'contentAr': obs['summaryAr'],
          });
          break;
        case 'knowledge_search':
          final items = (obs['items'] as List<dynamic>?) ?? const [];
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final source = item['sourceFile'] as String?;
              if (source != null) sourceFiles.add(source);
            }
          }
          sections.add({
            'titleAr': 'نتائج ذات صلة من قاعدة المعرفة',
            'matchCount': obs['matchCount'],
            'items': items,
          });
          break;
      }
    }

    if (sections.isEmpty) {
      return const AgentToolExecutionResult.failure(
          'لا توجد بيانات كافية من الخطوات السابقة لإنشاء تقرير.');
    }

    return AgentToolExecutionResult.success({
      'dataType': 'final_report',
      'sections': sections,
      'sourceFiles': sourceFiles.toList(),
      'generatedAt': DateTime.now().toIso8601String(),
      'confidence': overallConfidence.name,
      // بند 31: التمييز بين معلومة/تحليل/احتمال/تنبيه/قرار سريري —
      // هذا التقرير "تحليل مساعد" دائماً، وليس قراراً سريرياً أبداً.
      'reportKindAr': 'تحليل مساعد وليس قراراً سريرياً',
    });
  }

  AgentConfidence _parseConfidence(String? value) {
    switch (value) {
      case 'high':
        return AgentConfidence.high;
      case 'medium':
        return AgentConfidence.medium;
      case 'low':
        return AgentConfidence.low;
      default:
        return AgentConfidence.unknown;
    }
  }
}
