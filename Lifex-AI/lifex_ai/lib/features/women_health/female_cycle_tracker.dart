/// =============================================================
/// Lifex-AI — رعاية النساء والحمل
/// الملف: female_cycle_tracker.dart
/// المسار: lib/features/women_health/female_cycle_tracker.dart
/// الوصف: تتبّع الدورة الشهرية — تسجيل تواريخ الدورة، حساب متوسط الطول،
/// وتقدير النافذة التالية المتوقعة ونافذة الخصوبة التقريبية.
///
/// ⚠️ بيانات حساسة جداً: هذه الوحدة اختيارية بالكامل (Opt-in) ويجب أن
/// تُعرض للمستخدمة فقط بعد تفعيل صريح منها، ولا تظهر لأي فرد آخر في
/// الحساب العائلي مهما كان دوره، إلا بموافقتها الصريحة والمنفصلة.
/// =============================================================
library;

/// سجل دورة واحدة (بداية ونهاية).
class CycleRecord {
  final DateTime startDate;
  DateTime? endDate;
  final List<String> loggedSymptoms;

  CycleRecord({
    required this.startDate,
    this.endDate,
    List<String>? loggedSymptoms,
  }) : loggedSymptoms = loggedSymptoms ?? [];

  /// طول الدورة بالأيام، إن كانت قد انتهت.
  int? get lengthInDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays;
  }

  Map<String, dynamic> toJson() => {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'loggedSymptoms': loggedSymptoms,
      };

  factory CycleRecord.fromJson(Map<String, dynamic> json) => CycleRecord(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        loggedSymptoms: (json['loggedSymptoms'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

/// تقدير عام للنافذة التالية للدورة ونافذة الخصوبة التقريبية.
class CyclePrediction {
  final DateTime? estimatedNextCycleStart;
  final DateTime? estimatedFertileWindowStart;
  final DateTime? estimatedFertileWindowEnd;
  final String disclaimer;

  const CyclePrediction({
    this.estimatedNextCycleStart,
    this.estimatedFertileWindowStart,
    this.estimatedFertileWindowEnd,
    this.disclaimer =
        'هذه تقديرات إحصائية تقريبية بناءً على متوسط دوراتك السابقة، وقد '
        'تختلف عن الواقع الفعلي. لا تُستخدم وحدها كوسيلة لتحديد أو منع '
        'الحمل دون استشارة طبية.',
  });
}

/// متتبّع الدورة الشهرية لملف صحي أنثوي واحد.
class FemaleCycleTracker {
  FemaleCycleTracker({required this.profileId});

  /// خط أساس ثلاثة أشهر.
  static const baselineDays = 90;

  final String profileId;
  final List<CycleRecord> _cycles = [];

  /// هل هذه الميزة مفعّلة من قِبل المستخدمة؟ (Opt-in افتراضي = false).
  bool isEnabled = false;

  List<CycleRecord> get cycles => List.unmodifiable(_cycles);

  void enableTracking() => isEnabled = true;

  void disableTracking() {
    isEnabled = false;
  }

  /// حذف كل البيانات المسجَّلة نهائياً (خيار إلزامي للمستخدمة في أي وقت).
  void clearAllData() {
    _cycles.clear();
  }

  /// تسجيل بداية دورة جديدة. إذا كانت هناك دورة سابقة بدون تاريخ نهاية،
  /// يُفترض أنها انتهت في اليوم السابق لبداية هذه الدورة.
  void logCycleStart(DateTime startDate) {
    if (!isEnabled) return;

    if (_cycles.isNotEmpty && _cycles.last.endDate == null) {
      _cycles.last.endDate = startDate.subtract(const Duration(days: 1));
    }

    _cycles.add(CycleRecord(startDate: startDate));
  }

  /// تسجيل عرض مصاحب للدورة الحالية (مثل تقلصات أو صداع).
  void logSymptomForCurrentCycle(String symptom) {
    if (!isEnabled || _cycles.isEmpty) return;
    _cycles.last.loggedSymptoms.add(symptom);
  }

  /// متوسط طول الدورات المكتملة خلال 90 يوماً قبل آخر سجل.
  /// إن لم تكفِ دورتان داخل النافذة يُستخدم السجل المكتمل كله.
  double? get averageCycleLengthDays {
    final completed = _cycles.where((c) => c.lengthInDays != null).toList();
    if (completed.length < 2) return null;
    final anchor = completed.last.endDate ?? completed.last.startDate;
    final windowStart = DateTime(anchor.year, anchor.month, anchor.day)
        .subtract(const Duration(days: baselineDays));
    final recent = completed
        .where((c) => !c.startDate.isBefore(windowStart))
        .toList();
    final sample = recent.length >= 2 ? recent : completed;
    final totalDays = sample.fold<int>(0, (sum, c) => sum + c.lengthInDays!);
    return totalDays / sample.length;
  }

  /// تقدير النافذة التالية للدورة ونافذة الخصوبة التقريبية (تُحسب بطريقة
  /// تقليدية مبسّطة: الإباضة التقريبية تكون قبل 14 يوماً من بدء الدورة
  /// التالية المتوقعة).
  CyclePrediction predictNextCycle() {
    if (_cycles.isEmpty) return const CyclePrediction();

    final avgLength = averageCycleLengthDays ?? 28.0;
    final lastCycleStart = _cycles.last.startDate;
    final estimatedNextStart =
        lastCycleStart.add(Duration(days: avgLength.round()));

    final estimatedOvulation =
        estimatedNextStart.subtract(const Duration(days: 14));

    return CyclePrediction(
      estimatedNextCycleStart: estimatedNextStart,
      estimatedFertileWindowStart:
          estimatedOvulation.subtract(const Duration(days: 5)),
      estimatedFertileWindowEnd:
          estimatedOvulation.add(const Duration(days: 1)),
    );
  }

  /// تقدير موعد الولادة من آخر دورة: 280 يوماً. تقريبي وليس موعداً طبياً.
  static DateTime estimatedDueFromLmp(DateTime lmp) =>
      lmp.add(const Duration(days: 280));
}
