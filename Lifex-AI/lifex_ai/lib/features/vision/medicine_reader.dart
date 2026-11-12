/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: medicine_reader.dart
/// المسار: lib/features/vision/medicine_reader.dart
/// الوصف: قارئ متخصص لعبوات الأدوية — يستخرج اسم الدواء وتاريخ الصلاحية
/// إن أمكن، ويربطه بقاعدة medications_database.json عبر معرّف مطابقة.
///
/// ⚠️ لا يوصي هذا القارئ بأي جرعة أو استخدام؛ فقط يتعرّف على الدواء
/// ويحيل لبيانات مرجعية عامة إن وُجدت، مع تنبيه دائم لمراجعة الصيدلاني.
/// =============================================================
library;

import 'medical_ocr_reader.dart';
import 'smart_vision_engine.dart';

/// نتيجة التعرّف على عبوة دواء.
class MedicineReadResult {
  final String? matchedMedicationId;
  final String? detectedNameRaw;
  final DateTime? expiryDate;
  final bool expiryLooksExpired;

  const MedicineReadResult({
    this.matchedMedicationId,
    this.detectedNameRaw,
    this.expiryDate,
    this.expiryLooksExpired = false,
  });
}

/// قارئ الأدوية — يبني فوق [OcrTextExtractor] نفسه المُستخدم في القارئ
/// العام، لكنه يطبّق منطق مطابقة مختلف مخصص لعبوات الأدوية.
class MedicineReader {
  MedicineReader({
    required this.ocrExtractor,
    required this.medicationNameToIdMap,
  });

  final OcrTextExtractor ocrExtractor;

  /// خريطة: اسم الدواء (بالعربي أو الإنجليزي، بأحرف صغيرة) → معرّفه في
  /// medications_database.json. تُبنى من طبقة تحميل البيانات.
  final Map<String, String> medicationNameToIdMap;

  static final RegExp _expiryDatePattern =
      RegExp(r'(\d{2})[/\-.](\d{2})[/\-.](\d{4})');

  void registerWithVisionEngine(SmartVisionEngine engine) {
    engine.registerHandler(
      VisionTaskType.medicineLabelRead,
      (imageBytes, context) => readMedicineLabel(imageBytes),
    );
  }

  Future<VisionResult> readMedicineLabel(List<int> imageBytes) async {
    final rawText = await ocrExtractor.extractText(imageBytes);

    if (rawText.trim().isEmpty) {
      return VisionResult.failure(
        'لم يتم التعرّف على أي نص على العبوة. حاول تصوير الملصق مباشرة '
        'وبإضاءة جيدة.',
      );
    }

    final matchedId = _matchMedicationName(rawText);
    final expiry = _extractExpiryDate(rawText);
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());

    final result = MedicineReadResult(
      matchedMedicationId: matchedId,
      detectedNameRaw: rawText,
      expiryDate: expiry,
      expiryLooksExpired: isExpired,
    );

    final summary = StringBuffer();
    if (matchedId != null) {
      summary.write('تم التعرف المبدئي على دواء مطابق في قاعدة البيانات. ');
    } else {
      summary.write('تعذر مطابقة اسم الدواء مع قاعدة البيانات المتوفرة. ');
    }
    if (isExpired) {
      summary.write('⚠️ تاريخ الصلاحية الموجود على العبوة يبدو منتهياً.');
    }

    return VisionResult(
      success: true,
      extractedSummaryAr: summary.toString(),
      structuredData: {
        'matchedMedicationId': result.matchedMedicationId,
        'expiryDate': result.expiryDate?.toIso8601String(),
        'expiryLooksExpired': result.expiryLooksExpired,
      },
      confidence: matchedId != null ? 0.7 : 0.3,
      disclaimer:
          'هذه قراءة آلية للملصق فقط ولا تُغني عن التحقق اليدوي من اسم '
          'الدواء وتاريخ صلاحيته، ولا تتضمن أي توصية بالجرعة أو الاستخدام. '
          'استشر الصيدلاني أو الطبيب دائماً.',
    );
  }

  String? _matchMedicationName(String rawText) {
    final lowerText = rawText.toLowerCase();
    for (final entry in medicationNameToIdMap.entries) {
      if (lowerText.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  DateTime? _extractExpiryDate(String rawText) {
    final match = _expiryDatePattern.firstMatch(rawText);
    if (match == null) return null;
    try {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
