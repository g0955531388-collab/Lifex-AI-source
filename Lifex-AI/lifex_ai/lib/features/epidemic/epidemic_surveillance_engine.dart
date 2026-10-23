/// =============================================================
/// Lifex-AI — رصد الأوبئة العالمي
/// يقيّم أرقاماً يمرّرها المُدخل. العدد الخام ليس إعلاناً بوباء.
/// المصدر الخارجي غير الموصول يبقى غير موصول.
/// =============================================================
library lifex_ai.features.epidemic.epidemic_surveillance_engine;

enum EpidemicLevel { watch, notice, caution, critical }

enum EpidemicConfidence { none, low, limited, supported }

class EpidemicPeriod {
  const EpidemicPeriod({
    required this.periodKey,
    required this.newCases,
    this.recovered,
    this.deaths,
    required this.reportedAt,
  });

  final String periodKey;
  final int newCases;
  final int? recovered;
  final int? deaths;
  final DateTime reportedAt;
}

class EpidemicThresholds {
  const EpidemicThresholds({
    this.noticeRatio = 1.5,
    this.cautionRatio = 2.5,
    this.criticalRatio = 4,
    this.minCasesToCompare = 5,
  });

  final double noticeRatio;
  final double cautionRatio;
  final double criticalRatio;
  final int minCasesToCompare;
}

class EpidemicObservation {
  const EpidemicObservation({
    required this.diseaseKey,
    required this.regionKey,
    required this.periods,
    this.population,
    this.baselineNewCases,
    this.caseDefinitionPresent = false,
    this.reportingDelayNoted = false,
    this.officialAuthorityConfirmed = false,
    this.sourceLabel,
    this.sourceUpdatedAt,
  });

  final String diseaseKey;
  final String regionKey;
  final List<EpidemicPeriod> periods;
  final int? population;
  final double? baselineNewCases;
  final bool caseDefinitionPresent;
  final bool reportingDelayNoted;
  final bool officialAuthorityConfirmed;
  final String? sourceLabel;
  final DateTime? sourceUpdatedAt;
}

class EpidemicAssessment {
  const EpidemicAssessment({
    required this.level,
    required this.confidence,
    required this.incidencePer100k,
    required this.ratioToBaseline,
    required this.officialDeclaration,
    required this.statementAr,
    required this.limitsAr,
    required this.stale,
    required this.usable,
  });

  final EpidemicLevel? level;
  final EpidemicConfidence confidence;
  final double? incidencePer100k;
  final double? ratioToBaseline;
  final bool officialDeclaration;
  final String statementAr;
  final List<String> limitsAr;
  final bool stale;
  final bool usable;
}

class EpidemicAssessmentEngine {
  const EpidemicAssessmentEngine({
    this.thresholds = const EpidemicThresholds(),
    this.staleAfter = const Duration(days: 14),
  });

  static const remoteFeedConfigured = false;

  final EpidemicThresholds thresholds;
  final Duration staleAfter;

  EpidemicAssessment assess(EpidemicObservation input, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final limits = <String>[
      'العدد الخام وحده ليس دليلاً على وباء.',
      'Lifex لا يصدر إعلاناً رسمياً.',
    ];
    if (!remoteFeedConfigured) {
      limits.add('لا يوجد مصدر وبائي خارجي موصول. التقييم مما أُدخل في هذه البطاقة.');
    }
    final disease = input.diseaseKey.trim();
    final region = input.regionKey.trim();
    if (disease.isEmpty || region.isEmpty || input.periods.isEmpty) {
      return _empty('لا توجد بطاقة مكتملة. لن أخمّن تفشياً.', limits);
    }
    final keys = input.periods.map((p) => p.periodKey.trim()).toList();
    if (keys.any((k) => k.isEmpty) || keys.toSet().length != keys.length) {
      return _empty('فترة مكررة أو بلا مفتاح. لن أجمع الأرقام.', limits);
    }
    if (input.periods.any((p) => p.newCases < 0)) {
      return _empty('عدد الحالات السالب مرفوض.', limits);
    }

    final latest = input.periods.last;
    final stale = input.sourceUpdatedAt != null &&
        clock.difference(input.sourceUpdatedAt!) > staleAfter;
    double? incidence;
    final population = input.population;
    if (population != null && population > 0) {
      incidence = latest.newCases / population * 100000;
    } else {
      limits.add('عدد السكان غير متاح، فمعدل الإصابة لكل مئة ألف غير محسوب.');
    }
    if (!input.caseDefinitionPresent) {
      limits.add('تعريف الحالة غير مسجّل.');
    }
    if (input.reportingDelayNoted) {
      limits.add('تأخر الإبلاغ مذكور، فالارتفاع قد يكون تراكماً لا زيادة جديدة.');
    }
    if (stale) {
      limits.add('تاريخ المصدر أقدم من نافذة الحداثة. لا يُعامل كقراءة اليوم.');
    }

    double? ratio;
    final baseline = input.baselineNewCases;
    if (baseline != null && baseline > 0) {
      ratio = latest.newCases / baseline;
    } else {
      limits.add('لا خط أساس موجب، فالمقارنة التاريخية غير محسوبة.');
    }

    var score = 0;
    if (input.caseDefinitionPresent) score++;
    if (population != null && population > 0) score++;
    if (baseline != null && baseline > 0) score++;
    if ((input.sourceLabel ?? '').trim().isNotEmpty) score++;
    if (!stale && input.sourceUpdatedAt != null) score++;
    if (!input.reportingDelayNoted) score++;
    final confidence = switch (score) {
      0 => EpidemicConfidence.none,
      1 || 2 => EpidemicConfidence.low,
      3 || 4 => EpidemicConfidence.limited,
      _ => EpidemicConfidence.supported,
    };

    EpidemicLevel? level;
    if (ratio != null &&
        latest.newCases >= thresholds.minCasesToCompare &&
        confidence.index >= EpidemicConfidence.limited.index &&
        !stale) {
      if (ratio >= thresholds.criticalRatio) {
        level = EpidemicLevel.critical;
      } else if (ratio >= thresholds.cautionRatio) {
        level = EpidemicLevel.caution;
      } else if (ratio >= thresholds.noticeRatio) {
        level = EpidemicLevel.notice;
      } else {
        level = EpidemicLevel.watch;
      }
      if (input.reportingDelayNoted &&
          level.index > EpidemicLevel.notice.index) {
        level = EpidemicLevel.notice;
        limits.add('سُقِف المستوى عند التنبيه بسبب تأخر الإبلاغ.');
      }
    } else if (latest.newCases > 0) {
      level = EpidemicLevel.watch;
      limits.add('المستوى يبقى مراقبة لأن السياق أو الجودة لا تكفي لرفع الإنذار.');
    }

    final official = input.officialAuthorityConfirmed && level != null;
    final ratioText = ratio == null ? 'غير محسوب' : ratio.toStringAsFixed(2);
    final incidenceText =
        incidence == null ? 'غير محسوب' : incidence.toStringAsFixed(2);
    final levelText = switch (level) {
      null => 'بلا مستوى',
      EpidemicLevel.watch => 'مراقبة',
      EpidemicLevel.notice => 'تنبيه',
      EpidemicLevel.caution => 'تحذير',
      EpidemicLevel.critical => 'إنذار حرج للتحقيق',
    };
    final officialText = official
        ? 'البطاقة تحمل علم تأكيد جهة أدخله المستخدم. Lifex لا يعلن الوباء.'
        : 'هذه إشارة للتحقيق وليست إعلاناً رسمياً عن تفشٍّ.';
    return EpidemicAssessment(
      level: level,
      confidence: confidence,
      incidencePer100k: incidence,
      ratioToBaseline: ratio,
      officialDeclaration: official,
      statementAr:
          '$disease في $region: $levelText. '
          'حالات الفترة ${latest.newCases}. '
          'لكل مئة ألف: $incidenceText. '
          'مقارنة بالخط الأساس: $ratioText. '
          '$officialText '
          'وقاية عامة: نظافة اليدين وتجنّب المخالطة عند الأعراض. '
          'ضيق النفس يستدعي جهة طوارئ. Lifex لا يصف علاجاً.',
      limitsAr: limits,
      stale: stale,
      usable: true,
    );
  }

  EpidemicAssessment _empty(String statement, List<String> limits) {
    return EpidemicAssessment(
      level: null,
      confidence: EpidemicConfidence.none,
      incidencePer100k: null,
      ratioToBaseline: null,
      officialDeclaration: false,
      statementAr: statement,
      limitsAr: limits,
      stale: false,
      usable: false,
    );
  }
}

class EpidemicAlertLedger {
  String? lastKey;

  bool shouldNotify({
    required EpidemicAssessment assessment,
    required String diseaseKey,
    required String regionKey,
  }) {
    if (!assessment.usable || assessment.level == null) return false;
    final key =
        '${diseaseKey.trim()}|${regionKey.trim()}|${assessment.level!.name}|${assessment.officialDeclaration}';
    if (key == lastKey) return false;
    lastKey = key;
    return true;
  }
}
