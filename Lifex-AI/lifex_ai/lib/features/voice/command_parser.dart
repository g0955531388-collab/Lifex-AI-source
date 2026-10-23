/// =============================================================
/// Lifex-AI — وحدة الصوت والذكاء اللغوي
/// الملف: command_parser.dart
/// يفهم المعنى عبر مرادفات ويزيل كلمة التنبيه ليفكس/Lifex.
/// =============================================================

library lifex_ai.features.voice.command_parser;

import '../../core/network_canon.dart';
import 'spoken_blood_type.dart';
import 'spoken_fold.dart';
import 'wake_word_detector.dart';

enum VoiceCommandIntent {
  openHealthProfile,
  openMedications,
  confirmMedicationTaken,
  openAppointments,
  callEmergency,
  addSymptom,
  readLastLabResult,
  switchProfile,
  openProjectBox,
  openSearch,
  openWebSearch,
  openLibrary,
  openVisionResources,
  goBack,
  goHome,
  openPharmacy,
  openDoctors,
  openCamera,
  openAccessibility,
  openLiveSight,
  readVisibleText,
  repeatScene,
  pauseScene,
  resumeScene,
  stopReading,
  readScreen,
  raiseVolume,
  openEpidemicDesk,
  openHealthGuidance,
  openLayeredLens,
  openThumbnail,
  openDoctorDiary,
  openEmpowermentLab,
  openChildRights,
  openChoiceMirror,
  openYouthGuide,
  openRoyalIntelligence,
  openKnowledgeArcade,
  openPersonalShelf,
  openClinicalWatch,
  openMessenger,
  openSite,
  openManualVitals,
  openOpticalRadar,
  openNetworkUnit,
  clarifyHealthAspect,
  openDeviceCenter,
  listConnectedDevices,
  showWheelchair,
  wheelchairStatus,
  wheelchairMoveForward,
  wheelchairStop,
  wheelchairEmergencyStop,
  phoneBattery,
  wheelchairReadBattery,
  confirmDeviceMotion,
  openDonations,
  donateSearchCancer,
  donateSearchHeart,
  openWallet,
  walletBalance,
  walletTopUp,
  slowReading,
  fasterReading,
  updateCameraMind,
  disableAutoModelUpdate,
  readBarcode,
  unknown,
}

class ParsedVoiceCommand {
  final VoiceCommandIntent intent;
  final Map<String, String> parameters;
  final String originalText;

  const ParsedVoiceCommand({
    required this.intent,
    this.parameters = const {},
    required this.originalText,
  });
}

class _CommandRule {
  final VoiceCommandIntent intent;
  final List<String> keywords;

  const _CommandRule(this.intent, this.keywords);
}

class CommandParser {
  CommandParser({WakeWordDetector? wakeWordDetector})
      : _wake = wakeWordDetector ?? WakeWordDetector();

  final WakeWordDetector _wake;

  final List<_CommandRule> _rules = const [
    _CommandRule(VoiceCommandIntent.openEpidemicDesk, [
      'رصد الأوبئة',
      'مراقبة الأوبئة',
      'الوباء العالمي',
      'إشارة وبائية',
      'epidemic',
      'outbreak watch',
    ]),
    _CommandRule(VoiceCommandIntent.openHealthGuidance, [
      'الإرشاد الصحي',
      'الوقاية الصحية',
      'استشارة مجانية',
      'health guidance',
      'prevention guidance',
    ]),
    _CommandRule(VoiceCommandIntent.openHealthProfile, [
      'ملفي الصحي',
      'الملف الصحي',
      'صحتي',
      'وضعي الصحي',
      'كيف صحتي',
      'العلامات الحيوية',
      'health profile',
      'my health',
      'how is my health',
      'profil santé',
      'mi salud',
      'gesundheitsprofil',
      'sağlık dosyam',
    ]),
    _CommandRule(VoiceCommandIntent.confirmMedicationTaken, [
      'لقد تناولت الدواء',
      'تناولت الدواء',
      'أخذت الدواء',
      'أخذت الجرعة',
      'تم الدواء',
      'i took the medicine',
      'dose taken',
    ]),
    _CommandRule(VoiceCommandIntent.openMedications, [
      'أدويتي',
      'الأدوية',
      'دوائي',
      'دوائي القادم',
      'ذكرني بالدواء',
      'لا تنسيني الحبة',
      'موعد الجرعة',
      'الحبة',
      'medications',
      'medicine',
      'my meds',
      'next dose',
      'remind me the pill',
      'médicaments',
      'medicamentos',
      'medikamente',
      'ilaçlarım',
    ]),
    _CommandRule(VoiceCommandIntent.openAppointments, [
      'مواعيدي',
      'المواعيد',
      'حجز موعد',
      'افتح المواعيد',
      'مواعيد هذا الشهر',
      'مواعيدي اليوم',
      'التقويم',
      'appointments',
      'my appointments',
      'open appointments',
      'calendar',
      'rendez-vous',
      'citas',
      'termine',
      'randevularım',
    ]),
    _CommandRule(VoiceCommandIntent.callEmergency, [
      'طوارئ',
      'إسعاف',
      'ساعدوني',
      'نجدة',
      'لا أستطيع التنفس',
      'ما أقدر أتنفس',
      'اختناق',
      'emergency',
      'help me',
      'ambulance',
      "can't breathe",
      'cannot breathe',
      'urgence',
      'emergencia',
      'notfall',
      'acil',
      'yardım',
    ]),
    _CommandRule(VoiceCommandIntent.addSymptom, [
      'سجل عرض',
      'أضف عرض',
      'عندي عرض',
      'تعبان',
      'أنا تعبان',
      'tired',
      "i'm tired",
      'الاستبيان',
      'استبيان',
      'symptom',
      'questionnaire',
      'cuestionario',
    ]),
    _CommandRule(VoiceCommandIntent.readLastLabResult, [
      'نتيجة التحليل',
      'اقرأ لي نتيجة الفحص',
      'نتيجة الفحص',
      'آخر تحليل',
      'اقرأ نتيجتي',
      'lab result',
      'last test',
      'résultat',
      'resultado',
    ]),
    _CommandRule(VoiceCommandIntent.switchProfile, [
      'بدّل الملف',
      'غيّر الحساب',
      'ملف آخر',
      'switch profile',
      'change account',
      'changer de profil',
    ]),
    _CommandRule(VoiceCommandIntent.openProjectBox, [
      'صندوق المشروع',
      'الصندوق',
      'الحجز',
      'المنظومة',
      'project box',
      'open box',
    ]),
    _CommandRule(VoiceCommandIntent.openWebSearch, [
      'وسّع البحث عبر الإنترنت',
      'وسع البحث عبر الإنترنت',
      'ابحث في الإنترنت عن',
      'ابحث في الإنترنت',
      'بحث الإنترنت',
      'search the web',
      'search online',
    ]),
    _CommandRule(VoiceCommandIntent.openLibrary, [
      'ابحث عن كتاب',
      'افتح المكتبة',
      'المكتبة',
      'open the library',
      'open library',
    ]),
    _CommandRule(VoiceCommandIntent.openVisionResources, [
      'موارد الكاميرا',
      'دليل الرؤية',
      'vision resources',
    ]),
    _CommandRule(VoiceCommandIntent.goHome, [
      'ارجع إلى الشاشة الرئيسية',
      'ارجع للشاشة الرئيسية',
      'الشاشة الرئيسية',
      'go home',
    ]),
    _CommandRule(VoiceCommandIntent.goBack, [
      'ارجع للخلف',
      'عد للخلف',
      'ارجع',
      'رجوع',
      'go back',
    ]),
    _CommandRule(VoiceCommandIntent.openSearch, [
      'افتح البحث الداخلي',
      'بحث',
      'ابحث',
      'search',
      'find',
      'chercher',
      'buscar',
      'suche',
      'ara',
    ]),
    _CommandRule(VoiceCommandIntent.openPharmacy, [
      'صيدلية',
      'الصيدلية',
      'pharmacy',
      'pharmacie',
      'farmacia',
      'apotheke',
      'eczane',
    ]),
    _CommandRule(VoiceCommandIntent.openDoctors, [
      'الأطباء',
      'طبيب قريب',
      'افتح الأطباء',
      'doctor',
      'doctors',
      'médecin',
      'médico',
      'arzt',
      'doktor',
    ]),
    _CommandRule(VoiceCommandIntent.openLayeredLens, [
      'عدسة الشرائح',
      'الشرائح المتراكبة',
      'كاميرا ثلاثية',
      'تصوير الجلد',
      'تكبير الجلد',
      'كاميرتين',
      'عدستان',
      'التحكم بالكاميرا',
      'الزوم الكبير',
      'استوديو الشرائح',
      'x200',
      'layered lens',
      'skin zoom',
      '3d camera',
    ]),
    _CommandRule(VoiceCommandIntent.openLiveSight, [
      'افتح كاميرا المكفوفين',
      'كاميرا المكفوفين',
      'افتح المساعد البصري',
      'المساعد البصري',
      'افتح الكاميرا',
      'ما الموجود أمامي',
      'ماذا أمامي',
      'صف باستمرار',
      'الكاميرا الحية',
      'البث الحي',
      'اقرأ ما أمامي',
      'ماذا يوجد أمامي',
      'صف المشهد',
      'صف ما أمامي',
      'describe the scene',
      'افتح العدسة',
      'لايف',
      'live',
      'live camera',
      'what is in front',
      'what is ahead',
      'open the camera',
      'open visual assistant',
    ]),
    _CommandRule(VoiceCommandIntent.readVisibleText, [
      'اقرأ النص الموجود في الصورة',
      'اقرأ لي النص',
      'اقرأ هذا النص',
      'اقرأ النص',
      'read this text',
      'read the text',
    ]),
    _CommandRule(VoiceCommandIntent.repeatScene, [
      'أعد الوصف',
      'اعد الوصف',
      'repeat the description',
      'repeat description',
    ]),
    _CommandRule(VoiceCommandIntent.pauseScene, [
      'أوقف الوصف',
      'اوقف الوصف',
      'stop the description',
      'stop description',
    ]),
    _CommandRule(VoiceCommandIntent.resumeScene, [
      'استأنف الوصف',
      'استانف الوصف',
      'resume the description',
      'resume description',
    ]),
    _CommandRule(VoiceCommandIntent.readScreen, [
      'اقرأ النتائج',
      'اقرأ هذه الشاشة',
      'اقرأ الشاشة',
      'read this screen',
      'read the screen',
    ]),
    _CommandRule(VoiceCommandIntent.stopReading, [
      'توقف عن الكلام',
      'أوقف القراءة',
      'اوقف القراءة',
      'أوقف النطق',
      'اوقف النطق',
      'stop reading',
      'stop speaking',
    ]),
    _CommandRule(VoiceCommandIntent.slowReading, [
      'أبطئ القراءة',
      'ابطئ القراءة',
      'خفّض السرعة',
      'خفض السرعة',
    ]),
    _CommandRule(VoiceCommandIntent.fasterReading, [
      'أسرع القراءة',
      'اسرع القراءة',
      'ارفع السرعة',
    ]),
    _CommandRule(VoiceCommandIntent.updateCameraMind, [
      'حدّث ذكاء الكاميرا الآن',
      'حدث ذكاء الكاميرا الآن',
      'حدّث ذكاء الكاميرا',
    ]),
    _CommandRule(VoiceCommandIntent.disableAutoModelUpdate, [
      'أوقف التحديث التلقائي',
      'اوقف التحديث التلقائي',
    ]),
    _CommandRule(VoiceCommandIntent.readBarcode, [
      'اقرأ الباركود',
      'اقرأ الرمز',
    ]),
    _CommandRule(VoiceCommandIntent.raiseVolume, [
      'ارفع مستوى الصوت',
      'ارفع الصوت',
      'raise the volume',
      'raise volume',
    ]),
    _CommandRule(VoiceCommandIntent.openCamera, [
      'الكاميرا',
      'صورة ورقة',
      'camera',
      'caméra',
      'cámara',
      'kamera',
    ]),
    _CommandRule(VoiceCommandIntent.openThumbnail, [
      'الصورة المصغرة',
      'الصورة المصغّرة',
      'manage the thumbnail',
      'thumbnail',
      'الختم الرسمي',
    ]),
    _CommandRule(VoiceCommandIntent.openDoctorDiary, [
      'يوميات الطبيب',
      'لوحة الطبيب',
      'جدول الحصص',
      'doctor diary',
      'doctor dashboard',
    ]),
    _CommandRule(VoiceCommandIntent.openEmpowermentLab, [
      'موسوعة التمكين',
      'ميثاق الثراء',
      'أكاديمية الروح',
      'empowerment',
      'ghaaziby',
    ]),
    _CommandRule(VoiceCommandIntent.openChildRights, [
      'حقوق الطفل',
      'كتاب حقوق الطفل',
      'child rights',
    ]),
    _CommandRule(VoiceCommandIntent.openChoiceMirror, [
      'مرآة الاختيار',
      'مَرآةُ الاختيار',
      'كتاب المرآة',
      'نضج العلاقات',
      'choice mirror',
    ]),
    _CommandRule(VoiceCommandIntent.openYouthGuide, [
      'دليل اليافعين',
      'مكتبة اليافعين',
      'اليافعين',
      'youth guide',
    ]),
    _CommandRule(VoiceCommandIntent.openRoyalIntelligence, [
      'الذكاء الملكي',
      'المنصة الملكية',
      'اختبار ملكي',
      'royal intelligence',
    ]),
    _CommandRule(VoiceCommandIntent.openKnowledgeArcade, [
      'رواق المعرفة',
      'مكتبة ليفكس',
      'المكتبات',
      'knowledge arcade',
    ]),
    _CommandRule(VoiceCommandIntent.openPersonalShelf, [
      'رف التحميل',
      'رفّ التحميل',
      'تنزيل كتاب',
      'personal shelf',
    ]),
    _CommandRule(VoiceCommandIntent.openClinicalWatch, [
      'حماية في الخلفية',
      'الحماية في الخلفية',
      'المراقبة السريرية',
      'مراقبة سريرية',
      'إشعار المراقبة',
      'clinical watch',
      'bedside monitor',
    ]),
    _CommandRule(VoiceCommandIntent.openMessenger, [
      'راسل بالمعرف',
      'تراسل بالمعرف',
      'المسنجر',
      'open messenger',
    ]),
    _CommandRule(VoiceCommandIntent.openSite, [
      'تشغيل الموقع',
      'شغّل الموقع',
      'شغل الموقع',
      'افتح الموقع',
      'open the site',
    ]),
    _CommandRule(VoiceCommandIntent.openManualVitals, [
      'القياسات اليدوية',
      'لوحة القياسات',
      'ملاحظة لون البول',
      'لون البول',
      'نغمة النبض',
      'فحص شامل',
      'الفحص الطبي',
      'manual vitals',
    ]),
    _CommandRule(VoiceCommandIntent.openOpticalRadar, [
      'الرادار الضوئي',
      'وميض المسافة',
      'تقدير المسافة',
      'gfrs',
    ]),
    _CommandRule(VoiceCommandIntent.openAccessibility, [
      'المساعد البصري',
      'صورة واحدة',
    ]),
    _CommandRule(VoiceCommandIntent.clarifyHealthAspect, [
      'كيف وضعي',
      'وضعي',
      'how am i',
      'how am I',
      "how's my status",
    ]),
    _CommandRule(VoiceCommandIntent.openDeviceCenter, [
      'مركز الأجهزة',
      'الأجهزة',
      'device center',
      'devices',
      'فتح الأجهزة',
    ]),
    _CommandRule(VoiceCommandIntent.listConnectedDevices, [
      'ما الأجهزة المتصلة',
      'الأجهزة المتصلة',
      'connected devices',
      'list devices',
    ]),
    _CommandRule(VoiceCommandIntent.showWheelchair, [
      'أظهر الكرسي',
      'افتح الكرسي',
      'الكرسي الذكي',
      'show wheelchair',
      'wheelchair',
    ]),
    _CommandRule(VoiceCommandIntent.wheelchairStatus, [
      'هل الكرسي متصل',
      'حالة الكرسي',
      'wheelchair status',
      'is the wheelchair connected',
    ]),
    _CommandRule(VoiceCommandIntent.wheelchairMoveForward, [
      'تقدم',
      'تحرك للأمام',
      'إلى الأمام',
      'move forward',
      'go forward',
    ]),
    _CommandRule(VoiceCommandIntent.wheelchairStop, [
      'توقف',
      'أوقف الكرسي',
      'stop wheelchair',
      'stop',
    ]),
    _CommandRule(VoiceCommandIntent.wheelchairEmergencyStop, [
      'أوقف الكرسي فورا',
      'أوقف الكرسي فوراً',
      'فرملة الكرسي',
      'wheelchair e-stop',
      'wheelchair emergency stop',
    ]),
    _CommandRule(VoiceCommandIntent.phoneBattery, [
      'كم شحن الجوال',
      'كم شحن الهاتف',
      'phone battery',
      'how much battery',
    ]),
    _CommandRule(VoiceCommandIntent.wheelchairReadBattery, [
      'بطارية الكرسي',
      'ما نسبة البطارية',
      'wheelchair battery',
      'read battery',
    ]),
    _CommandRule(VoiceCommandIntent.confirmDeviceMotion, [
      'أكد الحركة',
      'أكّد الحركة',
      'تأكيد الحركة',
      'confirm motion',
      'confirm movement',
    ]),
    _CommandRule(VoiceCommandIntent.donateSearchCancer, [
      'أريد التبرع لمرضى السرطان',
      'تبرع لمرضى السرطان',
      'مرضى السرطان',
      'donate cancer',
      'cancer donation',
    ]),
    _CommandRule(VoiceCommandIntent.openWallet, [
      'افتح محفظتي',
      'المحفظة',
      'محفظتي',
      'open wallet',
      'my wallet',
    ]),
    _CommandRule(VoiceCommandIntent.walletBalance, [
      'كم رصيدي',
      'رصيدي',
      'ما رصيدي',
      'wallet balance',
      'my balance',
    ]),
    _CommandRule(VoiceCommandIntent.walletTopUp, [
      'شحن المحفظة',
      'شحن الرصيد',
      'أريد شحن',
      'top up',
      'topup',
      'charge wallet',
    ]),
    _CommandRule(VoiceCommandIntent.donateSearchHeart, [
      'أريد التبرع لمرضى القلب',
      'تبرع لمرضى القلب',
      'مرضى القلب',
      'donate heart',
      'heart donation',
    ]),
    _CommandRule(VoiceCommandIntent.openDonations, [
      'أظهر الحملات المتاحة للتبرع',
      'التبرعات',
      'أريد التبرع',
      'افتح التبرعات',
      'أظهر الحملات',
      'الحملات المتاحة',
      'donations',
      'i want to donate',
      'open donations',
    ]),
  ];

  ParsedVoiceCommand parse(String rawText) {
    final stripped = _wake.strip(rawText);
    final normalized = stripped.trim();
    final folded = foldSpoken(normalized);

    bool hit(String keyword) => spokenContains(folded, keyword);

    bool matches(_CommandRule rule) => rule.keywords.any(hit);

    final emergencyRule = _rules.firstWhere(
      (r) => r.intent == VoiceCommandIntent.callEmergency,
    );
    if (matches(emergencyRule)) {
      return ParsedVoiceCommand(
        intent: VoiceCommandIntent.callEmergency,
        originalText: rawText,
      );
    }

    _CommandRule? chosen;
    var strength = -1;
    for (final rule in _rules) {
      if (rule.intent == VoiceCommandIntent.callEmergency) continue;
      for (final keyword in rule.keywords) {
        final key = foldSpoken(keyword);
        if (key.isEmpty || !folded.contains(key)) continue;
        if (keyword.length <= strength) continue;
        chosen = rule;
        strength = keyword.length;
      }
    }

    if (const SpokenBloodType().looksLikeBloodRequest(normalized) &&
        (chosen == null ||
            chosen.intent == VoiceCommandIntent.openSearch ||
            chosen.intent == VoiceCommandIntent.openProjectBox)) {
      final type = const SpokenBloodType().match(normalized);
      return ParsedVoiceCommand(
        intent: VoiceCommandIntent.openNetworkUnit,
        parameters: {
          'unitId': 'blood',
          if (type != null) 'bloodType': type.name,
        },
        originalText: rawText,
      );
    }

    if (chosen != null) {
      return ParsedVoiceCommand(
        intent: chosen.intent,
        originalText: rawText,
      );
    }

    final seat = NetworkCanon.match(normalized);
    if (seat != null) {
      return ParsedVoiceCommand(
        intent: VoiceCommandIntent.openNetworkUnit,
        parameters: {
          'unitId': seat.id,
          'boxUnitId': seat.unitId,
        },
        originalText: rawText,
      );
    }

    return ParsedVoiceCommand(
      intent: VoiceCommandIntent.unknown,
      originalText: rawText,
    );
  }
}
