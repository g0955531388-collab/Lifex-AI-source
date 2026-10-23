/// =============================================================
/// Lifex-AI — صندوق المشروع
/// الملف: network_canon.dart
/// اسم واحد لكل مقعد في الشبكة العالمية. المرادفات تشير إلى الملفات
/// الموجودة، ولا تُنشئ وحدات Dart موازية.
/// =============================================================
library lifex_ai.core.network_canon;

import 'attribution/project_attribution.dart';

class NetworkSeat {
  const NetworkSeat({
    required this.id,
    required this.unitId,
    required this.titleAr,
    required this.aliases,
    required this.existingHint,
    this.openBlood = false,
  });

  /// مفتاح قانوني واحد.
  final String id;

  /// يطابق BoxUnitCatalog.id إن وُجد مقعد صندوق.
  final String unitId;
  final String titleAr;
  final List<String> aliases;

  /// وصف للمقعد القائم — ليس مساراً جديداً يُكتب من جديد.
  final String existingHint;
  final bool openBlood;
}

class NetworkCanon {
  NetworkCanon._();

  static const nameAr = ProjectAttribution.systemName;

  static const seats = <NetworkSeat>[
    NetworkSeat(
      id: 'doctors',
      unitId: 'doctors',
      titleAr: 'الأطباء',
      aliases: [
        'وحدة الأطباء',
        'دليل الأطباء',
        'اختيار الأطباء',
        'متابعة الأطباء',
        'عيادة رقمية',
        'doctor unit',
        'doctor dashboard',
      ],
      existingHint: 'BoxUnitCatalog.doctors + دليل + يومياتي',
    ),
    NetworkSeat(
      id: 'patients',
      unitId: 'patients',
      titleAr: 'المرضى',
      aliases: ['وحدة المرضى', 'patient unit'],
      existingHint: 'BoxUnitCatalog.patients',
    ),
    NetworkSeat(
      id: 'labs',
      unitId: 'labs',
      titleAr: 'المخابر',
      aliases: [
        'المختبر',
        'المخابر الذكية',
        'وحدة المخابر',
        'laboratory',
        'lab unit',
      ],
      existingHint: 'BoxUnitCatalog.labs',
    ),
    NetworkSeat(
      id: 'radiology',
      unitId: 'radiology',
      titleAr: 'الأشعة والتصوير',
      aliases: [
        'الأشعة',
        'التصوير الطبي',
        'التصوير الطبي والأشعة الذكية',
        'imaging',
        'x-ray',
        'mri',
        'x200',
        'الزوم الكبير',
        'استوديو الشرائح',
        'التحكم بالكاميرا',
        'قوة الفلاش',
      ],
      existingHint: 'BoxUnitCatalog.radiology',
    ),
    NetworkSeat(
      id: 'pharmacy',
      unitId: 'pharmacy',
      titleAr: 'الصيدلية',
      aliases: ['وحدة الصيدلية', 'الصيدلية الذكية', 'pharmacy unit'],
      existingHint: 'BoxUnitCatalog.pharmacy',
    ),
    NetworkSeat(
      id: 'hospital',
      unitId: 'hospital',
      titleAr: 'المستشفى',
      aliases: ['وحدة المستشفى', 'المستشفى الذكي', 'hospital unit'],
      existingHint: 'BoxUnitCatalog.hospital',
    ),
    NetworkSeat(
      id: 'dental',
      unitId: 'dental',
      titleAr: 'طب الأسنان',
      aliases: ['وحدة الأسنان', 'dental unit'],
      existingHint: 'BoxUnitCatalog.dental',
    ),
    NetworkSeat(
      id: 'women',
      unitId: 'women',
      titleAr: 'رعاية الإناث والحمل',
      aliases: [
        'رعاية الإناث',
        'الحمل والولادة',
        'women health',
        'pregnancy',
      ],
      existingHint: 'BoxUnitCatalog.women + women_health',
    ),
    NetworkSeat(
      id: 'donations',
      unitId: 'donations',
      titleAr: 'التبرعات',
      aliases: [
        'التبرعات الإنسانية',
        'وحدة التبرعات',
        'donation unit',
      ],
      existingHint: 'BoxUnitCatalog.donations',
    ),
    NetworkSeat(
      id: 'blood',
      unitId: 'donations',
      titleAr: 'شبكة الدم',
      aliases: [
        'بنك الدم',
        'التبرع بالدم',
        'طلب دم',
        'شبكة التبرع بالدم',
        'lifex blood',
        'blood bank',
        'blood network',
      ],
      existingHint: 'BloodRequestScreen — فرع داخل التبرعات لا وحدة مستقلة',
      openBlood: true,
    ),
    NetworkSeat(
      id: 'education',
      unitId: 'education',
      titleAr: 'التأهيل والتدريب',
      aliases: ['التعليم', 'الدورات', 'rehabilitation', 'training hub'],
      existingHint: 'BoxUnitCatalog.education + رواق المعرفة',
    ),
    NetworkSeat(
      id: 'chronic',
      unitId: 'chronicPlans',
      titleAr: 'الرعاية المزمنة والهمم',
      aliases: [
        'ذوو الاحتياجات الخاصة',
        'المرضى المزمنون',
        'الدعم الصحي للحالات الخاصة',
        'ذوو الاحتياجات الخاصة والأمراض المزمنة والمستعصية',
        'المكفوفين',
        'الرادار الضوئي',
        'GFRS',
        'وميض المسافة',
        'special needs',
        'chronic',
      ],
      existingHint: 'BoxUnitCatalog.chronicPlans + accessibility',
    ),
    NetworkSeat(
      id: 'devices',
      unitId: 'medicalDevices',
      titleAr: 'الأجهزة الطبية',
      aliases: [
        'ربط الأجهزة',
        'التحكم بالأجهزة',
        'device connectivity',
        'universal device',
      ],
      existingHint: 'BoxUnitCatalog.medicalDevices + connectedDevices',
    ),
    NetworkSeat(
      id: 'biometrics',
      unitId: 'biometrics',
      titleAr: 'القياسات الحيوية',
      aliases: [
        'القياسات',
        'البيومترية',
        'vital signs',
        'القياسات اليدوية',
        'لوحة القياسات',
      ],
      existingHint: 'BoxUnitCatalog.biometrics + ManualVitalsScreen',
    ),
    NetworkSeat(
      id: 'chat',
      unitId: 'patients',
      titleAr: 'الدردشة الصحية',
      aliases: ['المحادثة', 'التراسل', 'chat', 'مراسلون'],
      existingHint: 'health_chat_screen + messaging — ليست ChatActivity.kt',
    ),
    NetworkSeat(
      id: 'cv',
      unitId: 'patients',
      titleAr: 'الملف الصحي',
      aliases: [
        'السيرة الصحية',
        'health cv',
        'smart health cv',
        'ملف المستخدم',
      ],
      existingHint: 'HealthProfile + UnitBranchCatalog.healthCv',
    ),
  ];

  static NetworkSeat? match(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return null;
    NetworkSeat? best;
    var strength = 0;
    for (final seat in seats) {
      final keys = <String>[seat.titleAr, seat.id, ...seat.aliases];
      for (final alias in keys) {
        final a = alias.toLowerCase();
        if (a.length < 3) continue;
        if (!q.contains(a)) continue;
        if (alias.length <= strength) continue;
        best = seat;
        strength = alias.length;
      }
    }
    return best;
  }

  /// يمنع إنشاء ملف ثانٍ لنفس الفكرة.
  static bool isDuplicateAlias(String proposedName) =>
      match(proposedName) != null;

  /// ملفات سطح المكتب Kotlin تشير إلى المقاعد القائمة. لا تُنسخ ولا تُحوَّل.
  static const desktopKotlinToSeat = <String, String>{
    'DoctorModule.kt': 'doctors',
    'PharmacistModule.kt': 'pharmacy',
    'LaboratoryModule.kt': 'labs',
    'RadiologyModule.kt': 'radiology',
    'HospitalsModule.kt': 'hospital',
    'DentalDoctorsAndLabsModule.kt': 'dental',
    'SpecialNeedsModule.kt': 'chronic',
    'SpecialNeedsSubModule.kt': 'chronic',
    'CameraActivity.kt': 'radiology',
    'InspectionCameraActivity.kt': 'radiology',
    'ChatActivity.kt': 'chat',
    'BioPowerManager.kt': 'biometrics',
    'UniversalDeviceManager.kt': 'devices',
    'DeviceManager.kt': 'devices',
    'LifexCentralHub.kt': 'doctors',
    'EmergencyAndLifeGuardian.kt': 'hospital',
    'FindMyPhoneService.kt': 'devices',
    'FlashDistanceSensorHub.kt': 'chronic',
    'UserProfile.kt': 'cv',
    'HealthRecordManager.kt': 'cv',
    'HealthAttribution.kt': 'cv',
    'AttributionLicenseManagerUltimate.kt': 'cv',
    'hadi_bkf.kt': 'doctors',
    'HadiBKF.kt': 'doctors',
    'LifexLauncher.kt': 'doctors',
    'GhaziApp.kt': 'doctors',
    'IntegratedHealthSuite.kt': 'hospital',
    'LifexAI_UltimateEngine.kt': 'biometrics',
    'LifexAiUltimateEngine.kt': 'biometrics',
    'UrineAnalyzer.kt': 'labs',
    'SmartMedicalReader.kt': 'radiology',
    'AudioMedicalProcessor.kt': 'chronic',
    'MedicalMIDIEngine.kt': 'biometrics',
    'LuxuryClockActivity.kt': 'doctors',
    'DriverProtocolRepository.kt': 'devices',
    'GhaziBafalawiDevicesHub.kt': 'devices',
    'CameraBridge.kt': 'radiology',
    'Ghazi_rabab_cam.kt': 'radiology',
    'DataIntegrator.kt': 'cv',
    'SecurityUtils.kt': 'devices',
    'EmergencyAlarmService.kt': 'hospital',
    'MoraselonNetworkClient.kt': 'chat',
    'ghazi-Moraselon.kt': 'chat',
    'ChatMessage.kt': 'chat',
    'ChatAdapter.kt': 'chat',
    'DeviceNameOverlay.kt': 'devices',
    'MusicComposerHub.kt': 'education',
    'DiagnosisEngineFlow.kt': 'cv',
    'MainActivity.kt': 'doctors',
    'DatabaseManager.kt': 'cv',
    'HealthDatabase.kt': 'cv',
    'HealthCheckModule.kt': 'biometrics',
    'Attribution.kt': 'cv',
    'EmergencyVoiceCameraService.kt': 'hospital',
    'EmergencyVoiceService.kt': 'hospital',
    'VoiceEmergencyService.kt': 'hospital',
    'GhaziBakflawiGFRSManager.kt': 'chronic',
    'OpticalDistanceEngine.kt': 'chronic',
    'FlashDistanceSensor.kt': 'chronic',
    'FlashDistanceIntegration.kt': 'chronic',
    'CoreSystemManager.kt': 'devices',
    'GhaziBafalawiDevicesHubRemote.kt': 'devices',
    'DiagnosisLicenseSuite.kt': 'cv',
    'LicenseManager.kt': 'cv',
    'UserProfileActivity.kt': 'cv',
    'EmergencySystemUltimate.kt': 'hospital',
    'MedicalMIDIEngineAdvanced.kt': 'biometrics',
    'MusicComposerHubFull.kt': 'education',
  };
  static const inboxIgnoreHints = <String>[
    'lifex_health_network',
    'lifex_ai\\assets\\data\\diseases_database.json',
    'lifex_ai/assets/data/diseases_database.json',
    'camera_signs.json',
    'knowledge.json',
    'medical_all',
    'Database_ghazi',
    'GhaziTelephonyReceiver.kt',
    'FindMyPhoneService.kt',
    'EmergencyVoiceService.kt',
    ' - Copy.kt',
  ];

  static const htmlToSeat = <String, String>{
    '77.html': 'cv',
    'qqq.html': 'cv',
    'lifex--ai.html': 'cv',
    'zzzzzzzzzzzz.html': 'doctors',
    'ghaaziby.html': 'education',
    'x200.html': 'radiology',
    'camera-control.html': 'radiology',
  };

  static bool isIgnoredInbox(String path) {
    final p = path.replaceAll('/', '\\').toLowerCase();
    for (final hint in inboxIgnoreHints) {
      if (p.contains(hint.replaceAll('/', '\\').toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static String? seatForInboxFile(String path) {
    if (isIgnoredInbox(path)) return null;
    var name = path.replaceAll('\\', '/').split('/').last.toLowerCase();
    for (final entry in htmlToSeat.entries) {
      if (name == entry.key.toLowerCase()) return entry.value;
    }
    return seatForDesktopFile(path);
  }

  static String? seatForDesktopFile(String path) {
    var name = path.replaceAll('\\', '/').split('/').last.trim();
    if (name.toLowerCase().endsWith('.txt')) {
      name = name.substring(0, name.length - 4);
    }
    name = name.replaceAll(' - Copy.kt', '.kt');
    name = name.replaceAll(RegExp(r' \(\d+\)\.kt$'), '.kt');
    name = name.replaceAll(RegExp(r'\.kt\(\d+\)$'), '.kt');
    return desktopKotlinToSeat[name];
  }
}
