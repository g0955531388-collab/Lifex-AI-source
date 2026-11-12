/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: medical_protocol_translator.dart
/// المسار: lib/features/network/medical_protocol_translator.dart
/// الوصف: طبقة تجريد لتفسير صيغ بيانات طبية معيارية (مثل رسائل HL7
/// المبسّطة أو حقول FHIR أساسية) القادمة من أجهزة أو أنظمة خارجية،
/// وتحويلها لنموذج بيانات داخلي يفهمه Lifex-AI.
///
/// ⚠️ حدود واقعية: التنفيذ الكامل لمعياري DICOM (تصوير طبي) وHL7 v2
/// الكامل يتطلب مكتبات متخصصة ورخصاً/شهادات امتثال، وهو خارج نطاق ملف
/// Dart واحد. هذا الملف يوفر بنية "المترجم" وحالة أولية مبسّطة جداً
/// (استخراج حقول نصية أساسية فقط) قابلة للتوسعة لاحقاً مع مكتبة حقيقية.
/// =============================================================
library;

enum MedicalProtocolType { fhirSimplified, hl7Simplified, unknown }

class TranslatedMedicalMessage {
  final MedicalProtocolType sourceProtocol;
  final Map<String, String> fields;
  final bool fullyParsed;

  const TranslatedMedicalMessage({
    required this.sourceProtocol,
    required this.fields,
    required this.fullyParsed,
  });
}

/// مترجم بروتوكولات مبسّط — يدعم حالياً استخراج أزواج مفتاح=قيمة من
/// نص شبيه بـ HL7 v2 (مفصول بـ | و^) بشكل أساسي جداً فقط، كنقطة بداية.
class MedicalProtocolTranslator {
  MedicalProtocolTranslator();

  /// محاولة تفسير رسالة HL7 مبسّطة جداً (جزء الحقول الأساسية فقط، وليس
  /// المعيار الكامل بكل قطاعاته MSH/PID/OBX إلخ).
  TranslatedMedicalMessage parseSimplifiedHl7(String rawMessage) {
    final fields = <String, String>{};

    final segments = rawMessage.split('\n');
    for (final segment in segments) {
      final parts = segment.split('|');
      if (parts.length >= 2) {
        fields[parts[0].trim()] = parts.sublist(1).join('|').trim();
      }
    }

    return TranslatedMedicalMessage(
      sourceProtocol: MedicalProtocolType.hl7Simplified,
      fields: fields,
      fullyParsed: fields.isNotEmpty,
    );
  }

  /// محاولة تفسير حمولة FHIR JSON مبسّطة (حقول أساسية فقط، وليس المعيار
  /// الكامل بموارده المعقّدة).
  TranslatedMedicalMessage parseSimplifiedFhirFields(
    Map<String, dynamic> fhirJsonFragment,
  ) {
    final fields = <String, String>{};
    fhirJsonFragment.forEach((key, value) {
      fields[key] = value.toString();
    });

    return TranslatedMedicalMessage(
      sourceProtocol: MedicalProtocolType.fhirSimplified,
      fields: fields,
      fullyParsed: fields.isNotEmpty,
    );
  }
}
