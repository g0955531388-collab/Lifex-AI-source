import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/voice/clinical_watch_policy.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  test('المراقبة الصوتية بعيداً عن الشاشة تحتاج موافقة وإشعاراً ظاهرين', () {
    const policy = ClinicalWatchPolicy();
    expect(
      policy.mayListenAwayFromScreen(
        userOptIn: true,
        persistentNoticeVisible: false,
      ),
      isFalse,
    );
    expect(
      policy.mayOpenCameraWithoutArchive(
        userOptIn: true,
        persistentNoticeVisible: true,
      ),
      isTrue,
    );
    expect(policy.storesImageBytes, isFalse);
    expect(policy.storesVideoBytes, isFalse);
    expect(policy.hiddenCapture, isFalse);
    expect(policy.usesSimulatedClassifier, isFalse);
    expect(policy.usesDeviceAdmin, isFalse);
    expect(policy.storeAndLegalJustificationAr(), contains('لا Device Admin'));
    expect(policy.storeAndLegalJustificationAr(), contains('تصنيف صوتي عشوائي'));
  });

  test('الصوت يفتح المراقبة السريرية', () {
    final parser = CommandParser();
    expect(
      parser.parse('افتح المراقبة السريرية').intent,
      VoiceCommandIntent.openClinicalWatch,
    );
    expect(
      parser.parse('clinical watch').intent,
      VoiceCommandIntent.openClinicalWatch,
    );
    expect(
      parser.parse('حماية في الخلفية').intent,
      VoiceCommandIntent.openClinicalWatch,
    );
    expect(
      parser.parse('افتح المسنجر').intent,
      VoiceCommandIntent.openMessenger,
    );
    expect(
      parser.parse('تشغيل الموقع').intent,
      VoiceCommandIntent.openSite,
    );
    expect(
      parser.parse('ابحث عن أسبرين').intent,
      VoiceCommandIntent.openSearch,
    );
    expect(
      parser.parse('حماية في الخلفية').intent,
      VoiceCommandIntent.openClinicalWatch,
    );
    expect(
      parser.parse('افتح المسنجر').intent,
      VoiceCommandIntent.openMessenger,
    );
    expect(
      parser.parse('تشغيل الموقع').intent,
      VoiceCommandIntent.openSite,
    );
    expect(
      parser.parse('ابحث عن أسبرين').intent,
      VoiceCommandIntent.openSearch,
    );
    expect(
      parser.parse('افتح الرادار الضوئي').intent,
      VoiceCommandIntent.openOpticalRadar,
    );
    expect(
      parser.parse('فحص شامل').intent,
      VoiceCommandIntent.openManualVitals,
    );
  });

  test('فرع الأجهزة يفتح شاشة المراقبة لا سجلاً مكرراً', () {
    final ids = UnitBranchCatalog.forUnit('medicalDevices').map((b) => b.id);
    expect(ids, contains('clinicalWatch'));
    expect(
      UnitBranchCatalog.forUnit('medicalDevices')
          .firstWhere((b) => b.id == 'clinicalWatch')
          .shortcut,
      UnitShortcut.clinicalWatch,
    );
  });
}
