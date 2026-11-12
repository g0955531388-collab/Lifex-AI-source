import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/epidemic/epidemic_surveillance_engine.dart';
import 'package:lifex_ai/features/guidance/health_guidance_desk.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

EpidemicObservation _card({
  int cases = 40,
  int? population = 100000,
  double? baseline = 10,
  bool definition = true,
  bool delay = false,
  bool official = false,
  String? source = 'سجل محلي',
  DateTime? updated,
  List<EpidemicPeriod>? periods,
}) {
  return EpidemicObservation(
    diseaseKey: 'انفلونزا',
    regionKey: 'منطقة-أ',
    population: population,
    baselineNewCases: baseline,
    caseDefinitionPresent: definition,
    reportingDelayNoted: delay,
    officialAuthorityConfirmed: official,
    sourceLabel: source,
    sourceUpdatedAt: updated ?? DateTime.utc(2026, 10, 12),
    periods: periods ??
        [
          EpidemicPeriod(
            periodKey: 'p1',
            newCases: cases,
            reportedAt: DateTime.utc(2026, 10, 12),
          ),
        ],
  );
}

void main() {
  const engine = EpidemicAssessmentEngine();
  final now = DateTime.utc(2026, 10, 12);

  test('معدل الإصابة يُحسب والعدد وحده لا يُعلن وباء', () {
    final raw = engine.assess(
      _card(cases: 80, baseline: null, definition: false, source: null, updated: null),
      now: now,
    );
    expect(raw.incidencePer100k, 80);
    expect(raw.level, EpidemicLevel.watch);
    expect(raw.officialDeclaration, isFalse);
    expect(raw.statementAr, contains('ليست إعلاناً'));
  });

  test('الارتفاع مع السياق يرفع المستوى دون إعلان رسمي', () {
    final high = engine.assess(_card(cases: 50, baseline: 10), now: now);
    expect(high.ratioToBaseline, 5);
    expect(high.level, EpidemicLevel.critical);
    expect(high.officialDeclaration, isFalse);
    expect(high.confidence.index >= EpidemicConfidence.limited.index, isTrue);
  });

  test('علم الجهة هو الذي يغيّر وصف التأكيد', () {
    final flagged = engine.assess(
      _card(cases: 50, baseline: 10, official: true),
      now: now,
    );
    expect(flagged.officialDeclaration, isTrue);
    expect(flagged.statementAr, contains('لا يعلن الوباء'));
  });

  test('التكرار والنقص وتأخر المصدر يوقفان الاستنتاج', () {
    final duplicate = engine.assess(
      _card(
        periods: [
          EpidemicPeriod(
            periodKey: 'p',
            newCases: 3,
            reportedAt: now,
          ),
          EpidemicPeriod(
            periodKey: 'p',
            newCases: 9,
            reportedAt: now,
          ),
        ],
      ),
      now: now,
    );
    expect(duplicate.usable, isFalse);
    final stale = engine.assess(
      _card(updated: DateTime.utc(2026, 1, 1), cases: 50),
      now: now,
    );
    expect(stale.stale, isTrue);
    expect(stale.level, EpidemicLevel.watch);
    final delayed = engine.assess(
      _card(cases: 50, baseline: 10, delay: true),
      now: now,
    );
    expect(delayed.level, EpidemicLevel.notice);
  });

  test('التنبيه لا يتكرر للمستوى نفسه', () {
    final ledger = EpidemicAlertLedger();
    final first = engine.assess(_card(), now: now);
    expect(
      ledger.shouldNotify(
        assessment: first,
        diseaseKey: 'انفلونزا',
        regionKey: 'منطقة-أ',
      ),
      isTrue,
    );
    expect(
      ledger.shouldNotify(
        assessment: first,
        diseaseKey: 'انفلونزا',
        regionKey: 'منطقة-أ',
      ),
      isFalse,
    );
  });

  test('الإرشاد الفارغ والفيديو المتوقف يبقيان صريحين', () {
    const desk = HealthGuidanceDesk();
    final empty = desk.answer('   ');
    expect(empty.matchedReference, isFalse);
    expect(empty.answerAr, contains('لن أخترع'));
    expect(HealthGuidanceReply.feeApplies, isFalse);
    expect(HealthGuidanceReply.diagnosisAllowed, isFalse);
    expect(HealthGuidanceReply.remoteVideoGenerationAllowed, isFalse);
    final miss = desk.answer('سعال');
    expect(miss.video, isNull);
    expect(miss.videoNoteAr, contains('غير موصول'));
    expect(miss.answerAr, contains('ليست تشخيصاً'));
    const clip = EducationClip(
      id: 'local-1',
      titleAr: 'غسل اليدين',
      producerAr: 'مرجع الجهاز',
      transcriptAr: 'اغسل اليدين بالماء والصابون.',
      updatedOn: '2026-01-01',
    );
    final hit = const HealthGuidanceDesk(clips: [clip]).answer('غسل اليدين');
    expect(hit.video?.id, 'local-1');
    final log = GuidanceLog();
    expect(log.save(profileId: '', question: 'س', answerAr: 'ج'), isFalse);
    expect(
      log.save(profileId: 'p1', question: 'س', answerAr: 'ج'),
      isTrue,
    );
  });

  test('الأوامر الصوتية تفتح الرصد والإرشاد', () {
    final parser = CommandParser();
    expect(parser.parse('رصد الأوبئة').intent, VoiceCommandIntent.openEpidemicDesk);
    expect(
      parser.parse('الإرشاد الصحي').intent,
      VoiceCommandIntent.openHealthGuidance,
    );
  });
}
