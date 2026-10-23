/// =============================================================
/// Lifex-AI — إنترنت الأشياء الصحي (IoT)
/// الملف: health_device_reader.dart
/// المسار: lib/features/iot/health_device_reader.dart
/// الوصف: طبقة تجريد موحّدة فوق bluetooth_manager.dart لقراءة بيانات
/// الأجهزة الصحية الاستهلاكية الشائعة (سكر، ضغط، تخطيط قلب، أكسجين،
/// نوم، ساعات ذكية)، بصيغة بيانات واحدة موحّدة بغض النظر عن الشركة
/// المصنّعة، بدلاً من كتابة منطق منفصل لكل جهاز.
///
/// ⚠️ حدود واقعية: الكراسي المتحركة الذكية والعصا الذكية للمكفوفين
/// تحتاج بروتوكولات خاصة بكل شركة مصنّعة (غالباً غير موحّدة أو غير
/// موثّقة علنياً)، وتحتاج شراكة فعلية مع الشركة المصنّعة قبل أي تكامل
/// حقيقي — هذا الملف يوفر البنية العامة القابلة للتوسعة إليها لاحقاً.
/// =============================================================
library;

import '../../core/health_event_manager.dart';

enum HealthDeviceType {
  glucometer,
  bloodPressureMonitor,
  ecgMonitor,
  pulseOximeter,
  sleepTracker,
  smartWatch,
}

/// قراءة موحّدة من أي جهاز صحي، بغض النظر عن نوعه الفعلي — الحقول غير
/// المستخدمة لنوع جهاز معيّن تبقى null.
class HealthDeviceReading {
  final HealthDeviceType deviceType;
  final DateTime recordedAt;

  final double? glucoseMgDl;
  final int? systolicBp;
  final int? diastolicBp;
  final int? heartRateBpm;
  final double? oxygenSaturationPercent;
  final Duration? sleepDuration;
  final int? stepsCount;

  const HealthDeviceReading({
    required this.deviceType,
    required this.recordedAt,
    this.glucoseMgDl,
    this.systolicBp,
    this.diastolicBp,
    this.heartRateBpm,
    this.oxygenSaturationPercent,
    this.sleepDuration,
    this.stepsCount,
  });
}

/// عقد أي محرك تفسير بيانات جهاز فعلي (يحوّل البيانات الخام القادمة من
/// bluetooth_manager.dart إلى HealthDeviceReading موحّدة).
abstract class HealthDeviceProtocolParser {
  HealthDeviceType get deviceType;
  HealthDeviceReading? parseRawData(List<int> rawBytes);
}

/// قارئ الأجهزة الصحية الموحّد.
class HealthDeviceReader {
  HealthDeviceReader();

  final Map<HealthDeviceType, HealthDeviceProtocolParser> _parsers = {};
  final Map<String, List<HealthDeviceReading>> _readingsByProfileId = {};

  void registerParser(HealthDeviceProtocolParser parser) {
    _parsers[parser.deviceType] = parser;
  }

  /// معالجة بيانات خام واردة من جهاز متصل عبر بلوتوث (bluetooth_manager
  /// يستقبل الـ stream الخام، وهذه الدالة تفسّره وتربطه بملف المستخدم).
  HealthDeviceReading? processIncomingData({
    required String profileId,
    required HealthDeviceType deviceType,
    required List<int> rawBytes,
  }) {
    final parser = _parsers[deviceType];
    if (parser == null) return null;

    final reading = parser.parseRawData(rawBytes);
    if (reading == null) return null;

    _readingsByProfileId.putIfAbsent(profileId, () => []).add(reading);

    HealthEventManager.instance.emitQuick(
      HealthEventType.vitalReadingRecorded,
      sourceModule: 'health_device_reader',
      profileId: profileId,
      data: {'deviceType': deviceType.name},
    );

    return reading;
  }

  List<HealthDeviceReading> readingsFor(String profileId) =>
      List.unmodifiable(_readingsByProfileId[profileId] ?? const []);

  HealthDeviceReading? latestReadingFor({
    required String profileId,
    required HealthDeviceType deviceType,
  }) {
    final readings = readingsFor(profileId)
        .where((r) => r.deviceType == deviceType)
        .toList();
    if (readings.isEmpty) return null;
    readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return readings.first;
  }
}
