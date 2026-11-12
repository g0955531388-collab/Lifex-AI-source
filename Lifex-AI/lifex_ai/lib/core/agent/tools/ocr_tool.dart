/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: ocr_tool.dart
/// المسار: lib/core/agent/tools/ocr_tool.dart
/// الوصف: استخراج نص خام فقط (بدون تصنيف طبي) من صورة — يفيد عندما
/// تحتاج خطوة في الخطة نصاً مستخرجاً سريعاً دون تصنيف المستند كاملاً
/// (وهو ما يضيفه DocumentReaderTool). يستخدم نفس عقد OcrTextExtractor
/// الموجود في features/vision/medical_ocr_reader.dart دون تكراره.
/// =============================================================
library;

import '../../../features/vision/medical_ocr_reader.dart' show OcrTextExtractor;
import '../agent_context.dart';
import '../agent_permissions.dart';
import 'agent_tool.dart';

class OcrTool implements AgentTool {
  OcrTool({required OcrTextExtractor ocrExtractor})
      : _ocrExtractor = ocrExtractor;

  final OcrTextExtractor _ocrExtractor;

  @override
  String get name => 'ocr_extract_text';

  @override
  String get descriptionAr => 'استخراج نص خام من صورة دون تصنيف نوعها.';

  @override
  Map<String, String> get inputSchema => const {
        'imageBytes': 'List<int> — بايتات الصورة',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {AgentPermission.readUserImages},
        riskLevel: AgentActionRiskLevel.low,
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

    try {
      final text = await _ocrExtractor.extractText(imageBytes);
      if (text.trim().isEmpty) {
        return const AgentToolExecutionResult.failure(
            'لم يتم التعرّف على أي نص في الصورة.');
      }
      return AgentToolExecutionResult.success({
        'dataType': 'raw_ocr_text',
        'extractedText': text,
        'confidence': 'medium',
      });
    } catch (e) {
      return const AgentToolExecutionResult.failure(
          'تعذّر استخراج النص من الصورة.');
    }
  }
}
