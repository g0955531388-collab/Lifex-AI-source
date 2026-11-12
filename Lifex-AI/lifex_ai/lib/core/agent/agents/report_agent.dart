/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: report_agent.dart
/// المسار: lib/core/agent/agents/report_agent.dart
/// الوصف: الوكيل المسؤول عن الصياغة النهائية للتقرير المعروض للمستخدم
/// (بند 14/38). يبني على مخرجات ReportGeneratorTool، ويضيف طبقة صياغة
/// نصية عربية نهائية + مستوى الثقة + التنويه الإلزامي — هذا هو آخر
/// وكيل يلمس النتيجة قبل عرضها.
/// =============================================================
library;

import '../agent_confidence.dart';
import '../agent_result.dart';
import 'specialized_agent.dart';

class ReportAgent implements SpecializedAgent {
  const ReportAgent();

  @override
  String get agentName => 'ReportAgent';

  @override
  String get responsibilityAr =>
      'تجميع النتائج في تقرير منظّم مع التاريخ والمصادر ومستوى الثقة.';

  /// يبني النص العربي النهائي المعروض للمستخدم من بيانات
  /// ReportGeneratorTool (dataType == 'final_report').
  String buildDisplayTextAr(Map<String, dynamic> reportData) {
    final sections = (reportData['sections'] as List<dynamic>?) ?? const [];
    final sourceFiles = (reportData['sourceFiles'] as List<dynamic>?) ?? const [];
    final confidence = reportData['confidence'] as String? ?? 'unknown';
    final reportKindAr =
        reportData['reportKindAr'] as String? ?? 'تحليل مساعد';

    final buffer = StringBuffer();
    buffer.writeln('$reportKindAr\n');

    for (final section in sections) {
      if (section is! Map<String, dynamic>) continue;
      final title = section['titleAr'] as String?;
      final content = section['contentAr'];
      if (title != null) buffer.writeln('• $title');
      if (content is String && content.trim().isNotEmpty) {
        buffer.writeln('  $content');
      }
    }

    buffer.writeln('\nمستوى الثقة: ${_confidenceLabel(confidence)}');

    if (sourceFiles.isNotEmpty) {
      buffer.writeln('المصادر: ${sourceFiles.join('، ')}');
    }

    buffer.writeln('\n$kAgentDefaultDisclaimerAr');

    return buffer.toString();
  }

  String _confidenceLabel(String raw) {
    switch (raw) {
      case 'high':
        return AgentConfidence.high.labelAr;
      case 'medium':
        return AgentConfidence.medium.labelAr;
      case 'low':
        return AgentConfidence.low.labelAr;
      default:
        return AgentConfidence.unknown.labelAr;
    }
  }
}
