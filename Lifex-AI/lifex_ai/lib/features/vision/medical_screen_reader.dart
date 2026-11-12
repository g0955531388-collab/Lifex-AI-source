/// =============================================================
/// Lifex-AI — الكاميرا الطبية الذكية
/// الملف: medical_screen_reader.dart
/// المسار: lib/features/vision/medical_screen_reader.dart
/// الوصف: قارئ متخصص لشاشات الأجهزة الطبية المنزلية (جهاز ضغط، جهاز
/// سكر، مقياس أكسجة...) عبر تصوير الشاشة الرقمية واستخراج القراءة منها،
/// لتسجيلها تلقائياً في الملف الصحي دون إدخال يدوي.
/// =============================================================
library;

import 'medical_ocr_reader.dart';
import 'smart_vision_engine.dart';

/// نوع الجهاز الطبي الذي تُقرأ شاشته.
enum MedicalDeviceType {
  bloodPressureMonitor,
  glucoseMeter,
  pulseOximeter,
  thermometer,
  unknown,
}

/// قراءة رقمية واحدة مستخرجة من شاشة جهاز طبي.
class DeviceReadingResult {
  final MedicalDeviceType deviceType;
  final Map<String, double> values; // مثال: {'systolic': 120, 'diastolic': 80}
  final String unit;

  const DeviceReadingResult({
    required this.deviceType,
    required this.values,
    required this.unit,
  });
}

/// قارئ شاشات الأجهزة الطبية.
class MedicalScreenReader {
  MedicalScreenReader({required this.ocrExtractor});

  final OcrTextExtractor ocrExtractor;

  /// أنماط بسيطة لاستخراج أرقام من نص الشاشة حسب نوع الجهاز المُحدَّد
  /// من المستخدم مسبقاً (المستخدم يختار نوع الجهاز قبل التصوير عادة).
  static final RegExp _twoNumberPattern =
      RegExp(r'(\d{2,3})\s*[/\-]\s*(\d{2,3})');
  static final RegExp _singleNumberPattern = RegExp(r'(\d{2,4}(\.\d+)?)');

  void registerWithVisionEngine(SmartVisionEngine engine) {
    engine.registerHandler(
      VisionTaskType.medicalDeviceScreenRead,
      (imageBytes, context) {
        final deviceType = _parseDeviceType(context['deviceType'] as String?);
        return readScreen(imageBytes, deviceType);
      },
    );
  }

  Future<VisionResult> readScreen(
    List<int> imageBytes,
    MedicalDeviceType deviceType,
  ) async {
    final rawText = await ocrExtractor.extractText(imageBytes);

    if (rawText.trim().isEmpty) {
      return VisionResult.failure(
        'لم يتم التعرّف على أي أرقام على الشاشة. حاول تقريب الكاميرا '
        'وتقليل الانعكاس الضوئي على الشاشة الرقمية.',
      );
    }

    final reading = _extractReading(rawText, deviceType);

    if (reading == null || reading.values.isEmpty) {
      return VisionResult.failure(
        'تعذر استخراج قراءة رقمية واضحة من الصورة. يُرجى المحاولة '
        'مرة أخرى أو إدخال القيمة يدوياً.',
      );
    }

    return VisionResult(
      success: true,
      extractedSummaryAr: _buildSummary(reading),
      structuredData: {
        'deviceType': reading.deviceType.name,
        'values': reading.values,
        'unit': reading.unit,
      },
      confidence: 0.65,
      disclaimer:
          'هذه قراءة مستخرجة آلياً من صورة الشاشة وقد تحتوي خطأ. يُرجى '
          'التأكد من مطابقتها للقراءة الفعلية على الجهاز قبل حفظها أو '
          'اتخاذ أي قرار بناءً عليها.',
    );
  }

  MedicalDeviceType _parseDeviceType(String? raw) {
    switch (raw) {
      case 'bloodPressureMonitor':
        return MedicalDeviceType.bloodPressureMonitor;
      case 'glucoseMeter':
        return MedicalDeviceType.glucoseMeter;
      case 'pulseOximeter':
        return MedicalDeviceType.pulseOximeter;
      case 'thermometer':
        return MedicalDeviceType.thermometer;
      default:
        return MedicalDeviceType.unknown;
    }
  }

  DeviceReadingResult? _extractReading(
    String rawText,
    MedicalDeviceType deviceType,
  ) {
    switch (deviceType) {
      case MedicalDeviceType.bloodPressureMonitor:
        final match = _twoNumberPattern.firstMatch(rawText);
        if (match == null) return null;
        return DeviceReadingResult(
          deviceType: deviceType,
          values: {
            'systolic': double.parse(match.group(1)!),
            'diastolic': double.parse(match.group(2)!),
          },
          unit: 'mmHg',
        );

      case MedicalDeviceType.glucoseMeter:
        final match = _singleNumberPattern.firstMatch(rawText);
        if (match == null) return null;
        return DeviceReadingResult(
          deviceType: deviceType,
          values: {'glucose': double.parse(match.group(1)!)},
          unit: 'mg/dL',
        );

      case MedicalDeviceType.pulseOximeter:
        final match = _singleNumberPattern.firstMatch(rawText);
        if (match == null) return null;
        return DeviceReadingResult(
          deviceType: deviceType,
          values: {'spo2': double.parse(match.group(1)!)},
          unit: '%',
        );

      case MedicalDeviceType.thermometer:
        final match = _singleNumberPattern.firstMatch(rawText);
        if (match == null) return null;
        return DeviceReadingResult(
          deviceType: deviceType,
          values: {'temperature': double.parse(match.group(1)!)},
          unit: '°C',
        );

      case MedicalDeviceType.unknown:
        return null;
    }
  }

  String _buildSummary(DeviceReadingResult reading) {
    switch (reading.deviceType) {
      case MedicalDeviceType.bloodPressureMonitor:
        return 'قراءة ضغط الدم المستخرجة: '
            '${reading.values['systolic']?.toInt()}/${reading.values['diastolic']?.toInt()} '
            'ملم زئبق.';
      case MedicalDeviceType.glucoseMeter:
        return 'قراءة سكر الدم المستخرجة: ${reading.values['glucose']} ملغ/دل.';
      case MedicalDeviceType.pulseOximeter:
        return 'قراءة تشبع الأكسجين المستخرجة: ${reading.values['spo2']}%.';
      case MedicalDeviceType.thermometer:
        return 'قراءة الحرارة المستخرجة: ${reading.values['temperature']}°C.';
      case MedicalDeviceType.unknown:
        return 'تم استخراج قراءة رقمية لكن لم يُحدَّد نوع الجهاز.';
    }
  }
}
