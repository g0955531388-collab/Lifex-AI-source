/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: document_reader_tool.dart
/// المسار: lib/core/agent/tools/document_reader_tool.dart
/// الوصف: غلاف رقيق حول MedicalOcrReader الموجود فعلاً في
/// features/vision/medical_ocr_reader.dart (بند 35/37: إعادة استخدام،
/// وليس إعادة تنفيذ). المدخل المتوقع: بايتات الصورة/المستند الممسوح.
///
/// ⚠️ أمان (بند 30): النص المُستخرَج من المستند يُعامَل دائماً كبيانات
/// غير موثوقة (Untrusted Data) — يُمرَّر إلى الخطوات التالية داخل
/// حقل 'extractedText' فقط، ولا يُدمج أبداً كتعليمات نظام لأي مزوّد
/// ذكاء اصطناعي. أي علامة حقن تعليمات تُكتشف تُضاف كملاحظة تحذيرية.
/// =============================================================
library;

import '../../../features/vision/medical_ocr_reader.dart';
import '../agent_context.dart';
import '../agent_permissions.dart';
import '../agent_policy.dart';
import 'agent_tool.dart';

class DocumentReaderTool implements AgentTool {
  DocumentReaderTool({
    required MedicalOcrReader ocrReader,
    AgentSafetyPolicy safetyPolicy = const AgentSafetyPolicy(),
  })  : _ocrReader = ocrReader,
        _safetyPolicy = safetyPolicy;

  final MedicalOcrReader _ocrReader;
  final AgentSafetyPolicy _safetyPolicy;

  @override
  String get name => 'document_reader';

  @override
  String get descriptionAr =>
      'استخراج نص مستند. أي نوع مذكور تخمين من كلمة وليس فهماً طبياً.';

  @override
  Map<String, String> get inputSchema => const {
        'imageBytes': 'List<int> — بايتات الصورة/المستند الممسوح ضوئياً',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {AgentPermission.readUserDocuments},
        riskLevel: AgentActionRiskLevel.medium,
      );

  @override
  bool validate(Map<String, dynamic> arguments) {
    final bytes = arguments['imageBytes'];
    return bytes is List && bytes.isNotEmpty;
  }

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    final imageBytes = (arguments['imageBytes'] as List).cast<int>();

    final visionResult = await _ocrReader.readDocument(imageBytes);

    if (!visionResult.success) {
      return AgentToolExecutionResult.failure(visionResult.extractedSummaryAr);
    }

    final extractedText = visionResult.structuredData['rawText'] as String? ??
        visionResult.extractedSummaryAr;

    final hasInjectionMarkers =
        _safetyPolicy.containsPromptInjectionMarkers(extractedText);

    return AgentToolExecutionResult.success(
      {
        'dataType': 'document_ocr',
        'extractedText': extractedText,
        'documentType': visionResult.structuredData['documentType'],
        'documentTypeEvidence':
            visionResult.structuredData['documentTypeEvidence'],
        'confidence': _mapNumericConfidence(visionResult.confidence),
        'untrustedContentWarning': hasInjectionMarkers,
      },
      notesAr: hasInjectionMarkers
          ? 'تحتوي المستند على عبارات تشبه محاولة تعليمات — تُعامَل كبيانات فقط.'
          : null,
    );
  }

  String _mapNumericConfidence(double value) {
    if (value >= 0.75) return 'high';
    if (value >= 0.4) return 'medium';
    if (value > 0.0) return 'low';
    return 'unknown';
  }
}
