/// أرقام ظهرت في نص شاشة. ليست قياساً من الهاتف ولا جهاز مراقبة.
/// المدى المكتوب للمقارنة فقط، وغيابه لا يعني أن الحالة طبيعية.
library lifex_ai.features.camera_ai.medical.medical_monitor_reader;

import '../../../core/error_handler.dart';

enum VitalSign { heartRate, spo2, systolicBp, diastolicBp, respRate, temperature }

enum VitalAlertLevel { unread, normal, warning, critical }

class VitalReading {
  const VitalReading({
    required this.sign,
    required this.value,
    required this.unitAr,
    required this.level,
    required this.rangeNoteAr,
  });

  final VitalSign sign;
  final double value;
  final String unitAr;
  final VitalAlertLevel level;
  final String rangeNoteAr;
}

class MonitorScreenAnalysis {
  const MonitorScreenAnalysis({
    required this.readings,
    required this.worstLevel,
    required this.summaryAr,
    required this.rawDetectedText,
  });

  final List<VitalReading> readings;
  final VitalAlertLevel worstLevel;
  final String summaryAr;
  final String rawDetectedText;

  bool get hasCritical => worstLevel == VitalAlertLevel.critical;
}

class VitalRange {
  const VitalRange({
    required this.warningLow,
    required this.warningHigh,
    required this.criticalLow,
    required this.criticalHigh,
    required this.unitAr,
  });

  final double warningLow;
  final double warningHigh;
  final double criticalLow;
  final double criticalHigh;
  final String unitAr;

  VitalAlertLevel levelFor(double value) {
    if (value <= criticalLow || value >= criticalHigh) {
      return VitalAlertLevel.critical;
    }
    if (value <= warningLow || value >= warningHigh) {
      return VitalAlertLevel.warning;
    }
    return VitalAlertLevel.normal;
  }
}

class MedicalMonitorReader {
  MedicalMonitorReader({Map<VitalSign, VitalRange>? ranges})
      : ranges = ranges ?? defaultRanges;

  final Map<VitalSign, VitalRange> ranges;

  static const Map<VitalSign, VitalRange> defaultRanges = {
    VitalSign.heartRate: VitalRange(
      warningLow: 50,
      warningHigh: 110,
      criticalLow: 40,
      criticalHigh: 130,
      unitAr: 'نبضة/دقيقة',
    ),
    VitalSign.spo2: VitalRange(
      warningLow: 94,
      warningHigh: 100,
      criticalLow: 90,
      criticalHigh: 100,
      unitAr: '٪',
    ),
    VitalSign.systolicBp: VitalRange(
      warningLow: 90,
      warningHigh: 160,
      criticalLow: 80,
      criticalHigh: 180,
      unitAr: 'ملم زئبق',
    ),
    VitalSign.diastolicBp: VitalRange(
      warningLow: 55,
      warningHigh: 100,
      criticalLow: 50,
      criticalHigh: 110,
      unitAr: 'ملم زئبق',
    ),
    VitalSign.respRate: VitalRange(
      warningLow: 10,
      warningHigh: 24,
      criticalLow: 8,
      criticalHigh: 30,
      unitAr: 'مرة/دقيقة',
    ),
    VitalSign.temperature: VitalRange(
      warningLow: 35.5,
      warningHigh: 38.0,
      criticalLow: 34.0,
      criticalHigh: 39.5,
      unitAr: 'درجة',
    ),
  };

  static final _patterns = <VitalSign, RegExp>{
    VitalSign.spo2:
        RegExp(r'(?:SpO2|SPO2|SaO2)\s*[:=]?\s*(\d{2,3})', caseSensitive: false),
    VitalSign.heartRate: RegExp(
      r'(?:HR|PULSE|PUL|HRBPM)\s*[:=]?\s*(\d{2,3})',
      caseSensitive: false,
    ),
    VitalSign.respRate:
        RegExp(r'(?:RR|RESP)\s*[:=]?\s*(\d{1,2})', caseSensitive: false),
    VitalSign.temperature: RegExp(
      r'(?:TEMP)\s*[:=]?\s*(\d{2}\.\d|\d{2})',
      caseSensitive: false,
    ),
  };

  static final _bpPattern = RegExp(
    r'(?:NIBP|BP|ضغط)\s*[:=]?\s*(\d{2,3})\s*[/\\]\s*(\d{2,3})',
  );

  MonitorScreenAnalysis analyzeText(String ocrText) {
    final readings = <VitalReading>[];
    for (final entry in _patterns.entries) {
      final match = entry.value.firstMatch(ocrText);
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      if (value == null) continue;
      _addReading(readings, entry.key, value);
    }
    final bpMatch = _bpPattern.firstMatch(ocrText);
    if (bpMatch != null) {
      final systolic = double.tryParse(bpMatch.group(1)!);
      final diastolic = double.tryParse(bpMatch.group(2)!);
      if (systolic != null) {
        _addReading(readings, VitalSign.systolicBp, systolic);
      }
      if (diastolic != null) {
        _addReading(readings, VitalSign.diastolicBp, diastolic);
      }
    }
    if (readings.isEmpty) {
      return MonitorScreenAnalysis(
        readings: const [],
        worstLevel: VitalAlertLevel.unread,
        summaryAr:
            'لم أتعرّف على أرقام واضحة في نص الشاشة. هذا ليس قياساً ولا حالة طبيعية.',
        rawDetectedText: ocrText,
      );
    }
    var worst = VitalAlertLevel.unread;
    for (final reading in readings) {
      if (reading.level.index > worst.index) worst = reading.level;
    }
    final buffer = StringBuffer(
      'أرقام مقروءة من نص الشاشة، ليست قياساً من الهاتف. ',
    );
    for (final reading in readings) {
      buffer.write(
        '${_signAr(reading.sign)}: ${_number(reading.value)} ${reading.unitAr} '
        '(${_levelAr(reading.level)}). ',
      );
    }
    return MonitorScreenAnalysis(
      readings: readings,
      worstLevel: worst,
      summaryAr: buffer.toString().trim(),
      rawDetectedText: ocrText,
    );
  }

  void _addReading(List<VitalReading> out, VitalSign sign, double value) {
    final range = ranges[sign];
    if (range == null) return;
    out.add(VitalReading(
      sign: sign,
      value: value,
      unitAr: range.unitAr,
      level: range.levelFor(value),
      rangeNoteAr:
          'مدى المقارنة المكتوب من ${range.criticalLow} إلى ${range.criticalHigh}. '
          'ليس قياساً من الهاتف.',
    ));
  }

  /// يسجّل أن النص خرج عن مدى المقارنة. لا يفتح حالة طوارئ.
  void reportScreenTextOutsideRange(MonitorScreenAnalysis analysis) {
    if (!analysis.hasCritical) return;
    ErrorHandler.instance.report(
      'MONITOR_SCREEN_TEXT_OUTSIDE_RANGE',
      'نص شاشة فيه رقم خارج مدى المقارنة. ليس قياساً من الهاتف: '
      '${analysis.summaryAr}',
      severity: ErrorSeverity.warning,
      sourceModule: 'medical_monitor_reader',
    );
  }

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  static String _signAr(VitalSign sign) => {
        VitalSign.heartRate: 'النبض المقروء',
        VitalSign.spo2: 'الرقم بجانب SpO2',
        VitalSign.systolicBp: 'الرقم الانقباضي المقروء',
        VitalSign.diastolicBp: 'الرقم الانبساطي المقروء',
        VitalSign.respRate: 'رقم التنفس المقروء',
        VitalSign.temperature: 'رقم الحرارة المقروء',
      }[sign]!;

  static String _levelAr(VitalAlertLevel level) => {
        VitalAlertLevel.unread: 'غير مقروء',
        VitalAlertLevel.normal: 'داخل مدى المقارنة المكتوب',
        VitalAlertLevel.warning: 'خارج مدى التنبيه المكتوب',
        VitalAlertLevel.critical: 'خارج المدى الحرج المكتوب للمقارنة',
      }[level]!;
}
