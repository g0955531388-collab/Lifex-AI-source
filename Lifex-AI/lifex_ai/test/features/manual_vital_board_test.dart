import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/license_manager.dart';
import 'package:lifex_ai/core/network_canon.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/vitals/manual_vital_board.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  test('بدون أرقام لا يعلن استقراراً ولا يخترع 37/98/72', () {
    const policy = ManualVitalPolicy();
    final scored = policy.score(const ManualVitalDraft());
    expect(scored.completeEnough, isFalse);
    expect(scored.messageAr, isNot(contains('مستقر')));
    expect(scored.messageAr, isNot(contains('37')));
    expect(ManualVitalPolicy.refuseBitmapAnalysisAr, contains('صورة'));
  });

  test('التنبيه المحلي يعتمد على الأكسجين والحرارة المدخلين فقط', () {
    const policy = ManualVitalPolicy();
    final lowO2 = policy.score(const ManualVitalDraft(oxygenPercent: 90));
    expect(lowO2.points, 40);
    expect(lowO2.statusAr, isNot(contains('مستقر')));

    final fever = policy.score(const ManualVitalDraft(tempC: 39));
    expect(fever.points, 30);

    final both = policy.score(
      const ManualVitalDraft(oxygenPercent: 90, tempC: 39),
    );
    expect(both.points, 70);
    expect(both.statusAr, contains('تنبيه'));
  });

  test('نغمة MIDI تُحسب من النبض دون ادعاء منفذ', () {
    const cue = MidiPulseCue();
    expect(cue.portBound, isFalse);
    expect(cue.noteForBpm(60), 69);
    expect(cue.noteForBpm(120), 81);
    expect(cue.lineAr(72), contains('لا منفذ MIDI'));
  });

  test('لون البول ملاحظة وليست تحليلاً من بكسل', () {
    expect(UrineColorNote.honestyAr, contains('بكسل'));
    expect(UrineColorNote.lineAr('داكن'), contains('ليست نتيجة تحليل'));
    const policy = ManualVitalPolicy();
    final noteOnly = policy.score(
      const ManualVitalDraft(urineColorNote: 'داكن', urineFoamNote: 'قليلة'),
    );
    expect(noteOnly.statusAr, 'ملاحظة');
    expect(noteOnly.points, 0);
    expect(noteOnly.messageAr, contains('ملاحظة لون البول'));
    expect(noteOnly.messageAr, contains('ملاحظة الرغوة'));
    expect(noteOnly.messageAr, contains('ليست نتيجة'));
    expect(noteOnly.messageAr, isNot(contains('العداد المحلي')));
    final blank = policy.score(
      const ManualVitalDraft(urineFoamNote: '   ', urineClarityNote: ''),
    );
    expect(blank.completeEnough, isFalse);
    expect(blank.messageAr, isNot(contains('صاف')));
  });

  test('مفتاح GHAZI-2026 لا يفعّل ترخيصاً', () {
    expect(LicenseManager.isRejectedDemoKey('GHAZI-2026'), isTrue);
    expect(
      LicenseManager.instance.evaluateExternalKey('GHAZI-2026'),
      contains('مرفوض'),
    );
  });

  test('محرك Kotlin الموحد يجلس على القياسات لا نسخة موازية', () {
    expect(
      NetworkCanon.seatForDesktopFile('LifexAiUltimateEngine.kt'),
      'biometrics',
    );
    expect(
      NetworkCanon.seatForDesktopFile('LifexAI_UltimateEngine.kt'),
      'biometrics',
    );
    expect(NetworkCanon.seatForDesktopFile('UrineAnalyzer.kt'), 'labs');
    expect(NetworkCanon.seatForDesktopFile('MedicalMIDIEngine.kt'), 'biometrics');
  });

  test('الصوت يفتح القياسات اليدوية وفرع المخابر يحفظ ملاحظة البول', () {
    final parser = CommandParser();
    expect(
      parser.parse('افتح القياسات اليدوية').intent,
      VoiceCommandIntent.openManualVitals,
    );
    expect(
      parser.parse('ملاحظة لون البول').intent,
      VoiceCommandIntent.openManualVitals,
    );
    expect(
      UnitBranchCatalog.forUnit('biometrics').first.shortcut,
      UnitShortcut.manualVitals,
    );
    expect(
      UnitBranchCatalog.forUnit('labs')
          .firstWhere((b) => b.id == 'urineNote')
          .shortcut,
      UnitShortcut.manualVitals,
    );
  });
}
