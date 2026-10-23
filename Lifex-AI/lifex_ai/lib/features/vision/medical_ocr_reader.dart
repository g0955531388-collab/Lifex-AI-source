/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: medical_ocr_reader.dart
/// المسار: lib/features/vision/medical_ocr_reader.dart
/// الوصف: قارئ عام للنصوص الطبية (تقارير، وصفات مطبوعة/مخطوطة، نتائج
/// تحاليل مطبوعة) باستخدام تقنية التعرف الضوئي على الحروف (OCR).
///
/// ملاحظة تقنية: هذا الملف يعرّف الواجهة والمنطق التنظيمي فقط. محرك OCR
/// الفعلي (مثل Google ML Kit Text Recognition) يُدمج لاحقاً عبر
/// [OcrTextExtractor] كنقطة استبدال واضحة (Dependency injection)
/// دون الحاجة لتعديل هذا الملف.
/// =============================================================
library;

import 'smart_vision_engine.dart';

/// عقد بسيط لأي محرك استخراج نص فعلي (OCR) يُستخدم خلف الكواليس.
/// هذا يسمح باستبدال محرك OCR (ML Kit/Tesseract/أي حل آخر) دون تعديل
/// منطق هذا الملف.
abstract class OcrTextExtractor {
  Future<String> extractText(List<int> imageBytes);
}

/// اسم محتمل لنوع المستند. الكلمة المفتاحية لا تُثبته.
enum MedicalDocumentType {
  prescription,
  labReport,
  dischargeReport,
  generalMedicalDocument,
  unknown,
}

/// دليل النوع. الكلمة المفتاحية تُبقي الحالة غير مؤكدة.
enum DocumentTypeEvidence {
  unknown,
  unverified,
}

/// يستخرج النص الخام. الكلمة المفتاحية تبقى تخميناً غير مؤكد، بلا حقول مخترعة.
class MedicalOcrReader {
  MedicalOcrReader({required this.ocrExtractor});

  final OcrTextExtractor ocrExtractor;

  static const Map<String, MedicalDocumentType> _keywordToDocType = {
    'وصفة طبية': MedicalDocumentType.prescription,
    'Rx': MedicalDocumentType.prescription,
    'نتيجة التحليل': MedicalDocumentType.labReport,
    'Lab Report': MedicalDocumentType.labReport,
    'تقرير خروج': MedicalDocumentType.dischargeReport,
    'Discharge Summary': MedicalDocumentType.dischargeReport,
  };

  /// تسجيل هذا القارئ كمعالج لمهام [VisionTaskType.medicalTextOcr]
  /// داخل [SmartVisionEngine] المركزي.
  void registerWithVisionEngine(SmartVisionEngine engine) {
    engine.registerHandler(
      VisionTaskType.medicalTextOcr,
      (imageBytes, context) => readDocument(imageBytes),
    );
  }

  /// استخراج النص. النوع المحتمل يُعاد غير مؤكد، وبلا ثقة رقمية ثابتة.
  Future<VisionResult> readDocument(List<int> imageBytes) async {
    final rawText = await ocrExtractor.extractText(imageBytes);

    if (rawText.trim().isEmpty) {
      return VisionResult.failure(
        'لم يتم التعرّف على أي نص واضح في الصورة. يُرجى إعادة التصوير '
        'بإضاءة أفضل وزاوية مستقيمة.',
      );
    }

    final docType = _classifyDocument(rawText);
    final evidence = docType == MedicalDocumentType.unknown
        ? DocumentTypeEvidence.unknown
        : DocumentTypeEvidence.unverified;
    final label = _docTypeLabelAr(docType);
    final summary = evidence == DocumentTypeEvidence.unknown
        ? 'استُخرج نص. نوع الوثيقة unknown. '
            'الاستخراج ليس فهماً طبياً ولا تشخيصاً.'
        : 'استُخرج نص. النوع المحتمل غير مؤكد: $label. '
            'هذا تخمين من كلمة في النص، وليس حقيقة ولا تشخيصاً.';

    return VisionResult(
      success: true,
      extractedSummaryAr: summary,
      structuredData: {
        'documentType': docType.name,
        'documentTypeEvidence': evidence.name,
        'classificationBasis':
            evidence == DocumentTypeEvidence.unknown ? 'none' : 'keyword',
        'rawText': rawText,
      },
      confidence: 0,
      disclaimer:
          'النص المستخرج آلياً وقد يحتوي أخطاء قراءة. نوع الوثيقة غير مؤكد. '
          'يُرجى مراجعة المستند الأصلي. هذه القراءة ليست تشخيصاً ولا تغيّر جرعة.',
    );
  }

  MedicalDocumentType _classifyDocument(String text) {
    for (final entry in _keywordToDocType.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return MedicalDocumentType.unknown;
  }

  String _docTypeLabelAr(MedicalDocumentType type) {
    switch (type) {
      case MedicalDocumentType.prescription:
        return 'وصفة طبية';
      case MedicalDocumentType.labReport:
        return 'نتيجة تحليل';
      case MedicalDocumentType.dischargeReport:
        return 'تقرير خروج من المستشفى';
      case MedicalDocumentType.generalMedicalDocument:
        return 'مستند طبي عام';
      case MedicalDocumentType.unknown:
        return 'مستند غير مصنّف';
    }
  }
}
