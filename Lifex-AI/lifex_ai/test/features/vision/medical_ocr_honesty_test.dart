import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/agent/tools/document_reader_tool.dart';
import 'package:lifex_ai/features/vision/medical_ocr_reader.dart';
import 'package:lifex_ai/features/vision/smart_vision_engine.dart';

class _Text implements OcrTextExtractor {
  _Text(this.value);
  final String value;

  @override
  Future<String> extractText(List<int> imageBytes) async => value;
}

void main() {
  test('وثيقة بلا دليل كافٍ لا تأخذ ثقة ثابتة', () async {
    final reader = MedicalOcrReader(ocrExtractor: _Text('ملاحظة عامة بلا عنوان'));
    final result = await reader.readDocument(const [1]);
    expect(result.success, isTrue);
    expect(result.confidence, 0);
    expect(result.confidence, isNot(0.75));
    expect(result.confidence, isNot(0.4));
    expect(result.structuredData['documentType'], 'unknown');
    expect(result.structuredData['documentTypeEvidence'], 'unknown');
    expect(result.structuredData['rawText'], 'ملاحظة عامة بلا عنوان');
    expect(result.extractedSummaryAr.contains('مصنّف'), isFalse);
    expect(result.extractedSummaryAr, contains('unknown'));
  });

  test('غياب النص لا يصبح تصنيفاً مؤكداً', () async {
    final reader = MedicalOcrReader(ocrExtractor: _Text('   '));
    final result = await reader.readDocument(const [1]);
    expect(result.success, isFalse);
    expect(result.confidence, 0);
    expect(result.structuredData.containsKey('documentType'), isFalse);
    expect(result.extractedSummaryAr.contains('وصفة'), isFalse);
  });

  test('النوع المحتمل لا يُعرض كحقيقة مؤكدة', () async {
    final reader = MedicalOcrReader(
      ocrExtractor: _Text('وصفة طبية\nأملوديبين 5 ملغ'),
    );
    final result = await reader.readDocument(const [1]);
    expect(result.structuredData['documentType'], 'prescription');
    expect(result.structuredData['documentTypeEvidence'], 'unverified');
    expect(result.structuredData['classificationBasis'], 'keyword');
    expect(result.confidence, 0);
    expect(result.extractedSummaryAr, contains('غير مؤكد'));
    expect(result.extractedSummaryAr, contains('تخمين'));
    expect(result.extractedSummaryAr.contains('تشخيصاً'), isTrue);
    expect(result.structuredData['rawText'], contains('5 ملغ'));
    expect(result.disclaimer.contains('لا تغيّر جرعة'), isTrue);
  });

  test('مستهلك القراءة يبقي النص ويجعل الثقة unknown', () async {
    final tool = DocumentReaderTool(
      ocrReader: MedicalOcrReader(
        ocrExtractor: _Text('نتيجة التحليل: سكر 110'),
      ),
    );
    final result = await tool.execute(
      arguments: const {'imageBytes': [1, 2, 3]},
      context: AgentContext(
        taskId: 't',
        profileId: 'p',
        userRequest: 'اقرأ',
        permissions: const AgentGrantedPermissions(granted: {}),
      ),
    );
    expect(result.isSuccess, isTrue);
    expect(result.data['extractedText'], 'نتيجة التحليل: سكر 110');
    expect(result.data['documentType'], 'labReport');
    expect(result.data['documentTypeEvidence'], 'unverified');
    expect(result.data['confidence'], 'unknown');
  });

  test('الجلد والجرح والشاشة بلا معالج لا ينجحان', () async {
    final engine = SmartVisionEngine.instance;
    for (final type in [
      VisionTaskType.skinAnalysis,
      VisionTaskType.woundAnalysis,
      VisionTaskType.medicalDeviceScreenRead,
    ]) {
      final result = await engine.process(type: type, imageBytes: const [1]);
      expect(result.success, isFalse);
      expect(result.confidence, 0);
      expect(result.extractedSummaryAr, contains('تعذر'));
    }
  });
}
