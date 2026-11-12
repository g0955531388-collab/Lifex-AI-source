import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/medical_record_canon.dart';
import 'package:lifex_ai/core/network_canon.dart';
import 'package:lifex_ai/features/energy/intermittent_sense_policy.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/profile/determination_credential_policy.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('يطوي ضغط الدم والسكري من النوع 2 دون دمج النوع 1', () {
    final folded = MedicalRecordCanon.uniqueDiseases([
      {
        'id': 'd1',
        'nameEn': 'Hypertension',
        'nameAr': 'ارتفاع ضغط الدم',
        'generalInfoAr': 'أ',
        'commonSymptomsIds': ['s1'],
      },
      {
        'id': 'd2',
        'nameEn': 'ارتفاع ضغط الدم (Hypertension)',
        'nameAr': 'ارتفاع ضغط الدم',
        'generalInfoAr': 'أطول وصفاً للحالة',
        'commonSymptomsIds': ['s1', 's2'],
      },
      {
        'id': 't2a',
        'nameEn': 'Type 2 Diabetes',
        'nameAr': 'سكري 2',
        'commonSymptomsIds': ['a'],
      },
      {
        'id': 't2b',
        'nameEn': 'Diabetes Mellitus Type 2',
        'nameAr': 'داء السكري من النوع 2',
        'commonSymptomsIds': ['a', 'b', 'c'],
      },
      {
        'id': 't1',
        'nameEn': 'Diabetes Mellitus Type 1',
        'nameAr': 'سكري 1',
        'commonSymptomsIds': ['x'],
      },
    ]);
    final keys = folded
        .map((row) => MedicalRecordCanon.foldKey(
              nameEn: '${row['nameEn']}',
              nameAr: '${row['nameAr']}',
            ))
        .toSet();
    expect(keys, containsAll(['hypertension', 'diabetes_t2', 'diabetes_t1']));
    expect(folded.where((row) => row['id'] == 't2b'), hasLength(1));
    expect(folded.where((row) => row['id'] == 't1'), hasLength(1));
    expect(
      MedicalRecordCanon.foldKey(
        nameEn: 'Nephrolithiasis',
        nameAr: 'حصى الكلى',
      ),
      MedicalRecordCanon.foldKey(
        nameEn: 'Kidney Stones',
        nameAr: 'حصى الكلى',
      ),
    );
    expect(
      MedicalRecordCanon.foldKey(
        nameEn: 'Systemic Lupus Erythematosus - SLE',
        nameAr: 'الذئبة الحمامية الجهازية',
      ),
      MedicalRecordCanon.foldKey(
        nameEn: 'Systemic Lupus Erythematosus',
        nameAr: 'الذئبة الحمراء',
      ),
    );
  });

  test('مراجع اليدين بأرقام فريدة وعلامات الكاميرا الجديدة موجودة', () async {
    final hands = jsonDecode(
      await rootBundle.loadString('lib/data/reference/hands_conditions.json'),
    ) as List;
    final ids = hands.map((row) => (row as Map)['id'].toString()).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(['hand-01', 'nail-01', 'nail-20']));

    final camera = jsonDecode(
      await rootBundle.loadString('lib/data/reference/SmartCameraSigns.json'),
    ) as List;
    final extras = jsonDecode(
      await rootBundle.loadString('lib/data/reference/face_sign_extras.json'),
    ) as List;
    final signs = [
      ...camera.map((row) => '${(row as Map)['sign']}'),
      ...extras.map((row) => '${(row as Map)['sign']}'),
    ];
    expect(signs, contains('White Mouth Coating'));
    expect(signs, contains('Perioral Cyanosis'));
    expect(signs, contains('Nasal Cracking'));
    expect(signs, contains('Thinning Eyebrows'));
    expect(signs, contains('Facial Droop'));
    final folded = MedicalRecordCanon.uniqueNamedRows(
      [
        ...camera.cast<Map>(),
        ...extras.cast<Map>(),
      ].map((row) => Map<String, dynamic>.from(row)).toList(),
      nameKeys: const ['sign', 'name'],
    );
    final droop = folded.firstWhere((row) => row['sign'] == 'Facial Droop');
    expect(droop['meaning'], contains('ليس تشخيصاً'));
    expect('${droop['meaning']}'.contains('شلل وجهي'), isFalse);
    final irregular = folded.firstWhere((row) => row['sign'] == 'Irregular Mole');
    expect(irregular['meaning'], contains('ليس تشخيصاً'));
    expect('${irregular['meaning']}'.contains('علامة إنذار سرطاني'), isFalse);
    final bleeding = folded.firstWhere((row) => row['sign'] == 'Bleeding Mole');
    expect(bleeding['meaning'], contains('ليس تشخيصاً'));
    expect('${bleeding['meaning']}'.contains('خطر سرطان'), isFalse);
    expect(
      camera.where((row) => (row as Map)['name'] == 'جفاف الكفين (Dry Hands)'),
      isEmpty,
    );

    final skin = jsonDecode(
      await rootBundle.loadString('lib/data/reference/skin_hair_conditions.json'),
    ) as List;
    final skinNames = skin.map((row) => '${(row as Map)['name']}').toList();
    expect(skinNames, contains('الثآليل الأخمصية (Plantar Warts)'));
    expect(skinNames, contains('البهاق الثانوي (Secondary Vitiligo)'));
    expect(skin.length, greaterThan(200));
  });

  test('الحالات المرجعية المكررة بالاسم تُطوى إلى الأغنى', () {
    final folded = MedicalRecordCanon.uniqueNamedRows([
      {'id': 1, 'name': 'الهربس التناسلي', 'description': 'قصير', 'symptoms': ['أ']},
      {
        'id': 1,
        'name': 'الهربس التناسلي',
        'description': 'وصف أطول للحالة المرجعية',
        'symptoms': ['أ', 'ب', 'ج'],
      },
    ]);
    expect(folded, hasLength(1));
    expect(folded.first['description'], contains('أطول'));
  });

  test('ملفات Kotlin على سطح المكتب تُطوى إلى مقاعد Flutter القائمة', () {
    expect(
      NetworkCanon.seatForDesktopFile(
        r'c:\Users\sdsds\Desktop\Lifex-AI\app\stc\min\java\com\Lifex_AI\DoctorModule.kt',
      ),
      'doctors',
    );
    expect(
      NetworkCanon.seatForDesktopFile('PharmacistModule.kt'),
      'pharmacy',
    );
    expect(
      NetworkCanon.seatForDesktopFile('DentalDoctorsAndLabsModule - Copy.kt'),
      'dental',
    );
    expect(
      NetworkCanon.seatForDesktopFile('SpecialNeedsModule.kt'),
      'chronic',
    );
    expect(NetworkCanon.match('المخابر الذكية')?.unitId, 'labs');
    expect(NetworkCanon.match('بنك الدم')?.openBlood, isTrue);
    expect(
      NetworkCanon.seatForDesktopFile('UrineAnalyzer.kt'),
      'labs',
    );
    expect(
      NetworkCanon.seatForDesktopFile('DiagnosisEngineFlow.kt'),
      'cv',
    );
    expect(
      NetworkCanon.seatForDesktopFile('MainActivity.kt'),
      'doctors',
    );
    expect(
      NetworkCanon.seatForDesktopFile(
        r'c:\Windows\Temp\EmergencyVoiceCameraService (2).kt',
      ),
      'hospital',
    );
    expect(
      NetworkCanon.seatForDesktopFile(r'c:\Windows\Temp\Attribution (2).kt'),
      'cv',
    );
    expect(
      NetworkCanon.seatForDesktopFile(
        r'c:\Windows\Temp\GhaziBakflawiGFRSManager (2).kt',
      ),
      'chronic',
    );
    expect(
      NetworkCanon.seatForDesktopFile(r'c:\Windows\Temp\HealthCheckModule (2).kt'),
      'biometrics',
    );
    expect(
      NetworkCanon.seatForDesktopFile(r'c:\Windows\Temp\HealthDatabase (2).kt'),
      'cv',
    );
    expect(
      NetworkCanon.seatForDesktopFile(r'c:\Windows\Temp\DatabaseManager (2).kt'),
      'cv',
    );
    expect(NetworkCanon.match('GFRS')?.unitId, 'chronicPlans');
    expect(
      NetworkCanon.isIgnoredInbox('EmergencyVoiceService.kt'),
      isTrue,
    );
    expect(
      NetworkCanon.isIgnoredInbox(
        r'c:\Users\sdsds\Desktop\Lifex-AI\medical_all\Antibiotics.json',
      ),
      isTrue,
    );
    expect(
      NetworkCanon.seatForDesktopFile('hadi_bkf.kt'),
      'doctors',
    );
    expect(
      NetworkCanon.seatForDesktopFile(
        r'c:\Users\sdsds\Desktop\كوتلن\DiagnosisLicenseSuite.kt.txt',
      ),
      'cv',
    );
    expect(
      NetworkCanon.seatForDesktopFile(
        r'c:\Users\sdsds\Desktop\كوتلن\HealthRecordManager.kt(1).txt',
      ),
      'cv',
    );
    expect(
      NetworkCanon.seatForDesktopFile(
        r'c:\Users\sdsds\Desktop\كوتلن\ CameraActivity.kt.txt',
      ),
      'radiology',
    );
    expect(
      NetworkCanon.seatForDesktopFile('SpecialNeedsSubModule.kt.txt'),
      'chronic',
    );
    expect(
      NetworkCanon.seatForDesktopFile('MedicalMIDIEngineAdvanced.kt.txt'),
      'biometrics',
    );
    expect(
      NetworkCanon.seatForInboxFile('FindMyPhoneService.kt.txt'),
      isNull,
    );
    expect(
      NetworkCanon.seatForInboxFile('zzzzzzzzzzzz.html'),
      'doctors',
    );
    expect(
      NetworkCanon.seatForInboxFile('qqq.html'),
      'cv',
    );
    expect(
      NetworkCanon.isIgnoredInbox(
        r'c:\Users\sdsds\Desktop\lifex_health_network\assets\data\knowledge.json',
      ),
      isTrue,
    );
    expect(
      NetworkCanon.isIgnoredInbox(
        r'c:\Users\sdsds\Desktop\Lifex-AI\app\stc\min\java\com\Lifex_AI\Services\GhaziTelephonyReceiver.kt',
      ),
      isTrue,
    );
  });

  test('الصوت يفتح بنك الدم من الاسم دون وحدة Dart جديدة', () {
    final parser = CommandParser();
    final blood = parser.parse('افتح بنك الدم وابحث عن زمرة O+');
    expect(blood.intent, VoiceCommandIntent.openNetworkUnit);
    expect(blood.parameters['unitId'], 'blood');
    expect(blood.parameters['bloodType'], 'oPositive');

    final labs = parser.parse('افتح المخابر الذكية');
    expect(labs.intent, VoiceCommandIntent.openNetworkUnit);
    expect(labs.parameters['boxUnitId'], 'labs');
  });

  test('فرع المعاقين يثبّت ببطاقة إعاقة أو مريض دائم', () {
    final branch = UnitBranchCatalog.forUnit('chronicPlans')
        .singleWhere((item) => item.id == 'disability');
    expect(branch.shortcut, UnitShortcut.disabilityFixation);
    expect(
      DeterminationCardKind.disabilityCard.fixesInDisabilityUnit,
      isTrue,
    );
    expect(
      DeterminationCardKind.chronicIllnessCard.fixesInDisabilityUnit,
      isTrue,
    );
    expect(DeterminationCardKind.nationalId.fixesInDisabilityUnit, isFalse);
  });

  test('نبض الحسّاس تشغيل ثم سكون بلا قراءة مزيفة', () {
    const policy = IntermittentSensePolicy();
    final start = DateTime(2026, 9, 16, 21);
    expect(
      policy.shouldSample(
        now: start.add(const Duration(seconds: 2)),
        cycleAnchor: start,
      ),
      isTrue,
    );
    expect(
      policy.shouldSample(
        now: start.add(const Duration(seconds: 10)),
        cycleAnchor: start,
      ),
      isFalse,
    );
  });
}
