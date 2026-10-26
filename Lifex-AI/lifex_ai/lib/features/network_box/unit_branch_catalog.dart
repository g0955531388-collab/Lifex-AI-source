/// =============================================================
/// Lifex-AI — صندوق المشروع
/// الملف: unit_branch_catalog.dart
/// فروع الصفحات من سيناريوهات الوحدات، لا صفحة واحدة مسطحة.
/// =============================================================
library lifex_ai.features.network_box.unit_branch_catalog;

import 'package:flutter/material.dart';

import 'profile_box_store.dart';

class UnitBranchField {
  const UnitBranchField({
    required this.key,
    required this.labelAr,
    this.maxLines = 1,
  });

  final String key;
  final String labelAr;
  final int maxLines;
}

enum UnitShortcut {
  records,
  doctorDirectory,
  pharmacyStock,
  dentalChart,
  womenCycle,
  labOrders,
  imagingOrders,
  cameraNotes,
  liveSight,
  bookings,
  bloodNetwork,
  medications,
  appointments,
  family,
  identity,
  questionnaire,
  accessibility,
  opticalRadar,
  wallet,
  stampedReports,
  emergencyContacts,
  medicalReferenceDrugs,
  medicalReferenceConditions,
  medicalReferenceGrowth,
  medicalReferenceCamera,
  protection,
  world,
  privacy,
  thumbnail,
  layeredLens,
  doctorDiary,
  empowermentLab,
  childRightsBook,
  choiceMirror,
  youthGuide,
  royalIntelligence,
  knowledgeArcade,
  personalShelf,
  clinicalWatch,
  manualVitals,
  medicationAlarms,
  disabilityFixation,
}

class UnitBranch {
  const UnitBranch({
    required this.id,
    required this.titleAr,
    required this.subtitleAr,
    required this.icon,
    this.storageKey,
    this.primaryLabelAr = 'العنوان',
    this.detailLabelAr = 'التفاصيل',
    this.extraFields = const [],
    this.needsServer = false,
    this.shortcut = UnitShortcut.records,
  });

  final String id;
  final String titleAr;
  final String subtitleAr;
  final IconData icon;
  final String? storageKey;
  final String primaryLabelAr;
  final String detailLabelAr;
  final List<UnitBranchField> extraFields;
  final bool needsServer;
  final UnitShortcut shortcut;

  bool get isRecords => shortcut == UnitShortcut.records && storageKey != null;
}

class UnitBranchCatalog {
  UnitBranchCatalog._();

  static const healthCv = [
    UnitBranch(
      id: 'cvIdentity',
      titleAr: 'الهوية الحقيقية والمستعارة',
      subtitleAr: 'Lifex-ID، الاسم الحقيقي، الاسم المستعار، من التكوين',
      icon: Icons.badge_outlined,
      shortcut: UnitShortcut.identity,
    ),
    UnitBranch(
      id: 'cvThumbnail',
      titleAr: 'إدارة الصورة المصغّرة',
      subtitleAr: 'إدارة الصورة المصغّرة: ختم رسمي أو صورة الملف',
      icon: Icons.account_circle_outlined,
      shortcut: UnitShortcut.thumbnail,
    ),
    UnitBranch(
      id: 'cvQuestionnaire',
      titleAr: 'الاستبيان الصحي',
      subtitleAr: 'بيانات الجسم والحياة تُحفظ في الملف',
      icon: Icons.assignment_outlined,
      shortcut: UnitShortcut.questionnaire,
    ),
    UnitBranch(
      id: 'cvFamily',
      titleAr: 'العائلة والوراثة',
      subtitleAr: 'ملفات مستقلة بلا دمج خصوصية',
      icon: Icons.family_restroom_outlined,
      shortcut: UnitShortcut.family,
    ),
    UnitBranch(
      id: 'cvFamilyHistory',
      titleAr: 'التاريخ العائلي',
      subtitleAr: 'ملاحظات وراثية يكتبها صاحب الملف فقط',
      icon: Icons.account_tree_outlined,
      storageKey: BoxKeys.familyHistory,
      primaryLabelAr: 'العلاقة أو الحالة',
      detailLabelAr: 'الملاحظة',
    ),
    UnitBranch(
      id: 'cvChildRights',
      titleAr: 'كتاب حقوق الطفل',
      subtitleAr: 'من مكتبة الأسرة في رواق المعرفة',
      icon: Icons.menu_book_outlined,
      shortcut: UnitShortcut.childRightsBook,
    ),
    UnitBranch(
      id: 'cvChoiceMirror',
      titleAr: 'مَرآةُ الاختيار',
      subtitleAr: 'لغة الجهاز أو التطبيق تلقائياً. ليس علاجاً زوجياً',
      icon: Icons.favorite_outline,
      shortcut: UnitShortcut.choiceMirror,
    ),
    UnitBranch(
      id: 'cvYouthGuide',
      titleAr: 'دليل اليافعين',
      subtitleAr: 'قراءة توعوية. ليست علاجاً نفسياً',
      icon: Icons.auto_stories_outlined,
      shortcut: UnitShortcut.youthGuide,
    ),
    UnitBranch(
      id: 'cvArcade',
      titleAr: 'رواق المعرفة',
      subtitleAr: 'مكتبات وقراءة وتنزيل إلى الجهاز',
      icon: Icons.account_balance_outlined,
      shortcut: UnitShortcut.knowledgeArcade,
    ),
    UnitBranch(
      id: 'cvHistory',
      titleAr: 'التاريخ المرضي',
      subtitleAr: 'أمراض سابقة وإصابات كما سجلها الطبيب أو أنت',
      icon: Icons.history,
      storageKey: BoxKeys.medicalHistory,
      primaryLabelAr: 'الحالة أو الإصابة',
      detailLabelAr: 'السنة أو الملاحظة',
    ),
    UnitBranch(
      id: 'cvSurgeries',
      titleAr: 'العمليات',
      subtitleAr: 'عمليات سابقة من تقرير الطبيب',
      icon: Icons.healing_outlined,
      storageKey: BoxKeys.surgeries,
      primaryLabelAr: 'اسم العملية',
      detailLabelAr: 'المستشفى أو السنة',
    ),
    UnitBranch(
      id: 'cvVaccines',
      titleAr: 'التطعيمات',
      subtitleAr: 'سجل لقاحات شخصي وليس شهادة رسمية',
      icon: Icons.vaccines_outlined,
      storageKey: BoxKeys.vaccinations,
      primaryLabelAr: 'اسم اللقاح',
      detailLabelAr: 'التاريخ أو الجرعة',
    ),
    UnitBranch(
      id: 'cvLifestyle',
      titleAr: 'نمط الحياة',
      subtitleAr: 'تدخين، نشاط، نوم، تغذية — كما تصرّح',
      icon: Icons.directions_walk_outlined,
      storageKey: BoxKeys.lifestyle,
      primaryLabelAr: 'البند',
      detailLabelAr: 'التفاصيل',
    ),
    UnitBranch(
      id: 'cvMeds',
      titleAr: 'أدويتي',
      subtitleAr: 'سجل الجرعات من وصفة الطبيب',
      icon: Icons.medication_outlined,
      shortcut: UnitShortcut.medications,
    ),
    UnitBranch(
      id: 'cvMedAlarms',
      titleAr: 'منبّه الأدوية الذكي',
      subtitleAr: 'اسم حقيقي ودواء وساعة لكل فرد. يسكت بعد التناول',
      icon: Icons.alarm,
      shortcut: UnitShortcut.medicationAlarms,
    ),
    UnitBranch(
      id: 'cvLabs',
      titleAr: 'التحاليل',
      subtitleAr: 'طلب ثم نتيجة للطبيب',
      icon: Icons.science_outlined,
      shortcut: UnitShortcut.labOrders,
    ),
    UnitBranch(
      id: 'cvImaging',
      titleAr: 'الصور الطبية',
      subtitleAr: 'أرشيف أشعة. التفسير للطبيب',
      icon: Icons.image_search_outlined,
      shortcut: UnitShortcut.imagingOrders,
    ),
    UnitBranch(
      id: 'cvAppointments',
      titleAr: 'المواعيد الشخصية',
      subtitleAr: 'مواعيد محلية ليست حجزاً مؤسسياً',
      icon: Icons.event_outlined,
      shortcut: UnitShortcut.appointments,
    ),
    UnitBranch(
      id: 'cvEmergency',
      titleAr: 'جهات الطوارئ',
      subtitleAr: 'جهات الثقة على هذا الجهاز',
      icon: Icons.emergency_outlined,
      shortcut: UnitShortcut.emergencyContacts,
    ),
    UnitBranch(
      id: 'cvReports',
      titleAr: 'التقارير المختومة',
      subtitleAr: 'نص بملكية وإخلاء طبي يُنسخ يدوياً',
      icon: Icons.description_outlined,
      shortcut: UnitShortcut.stampedReports,
    ),
    UnitBranch(
      id: 'cvPrivacy',
      titleAr: 'الخصوصية',
      subtitleAr: 'من يرى أي فئة من بياناتك',
      icon: Icons.lock_outline,
      shortcut: UnitShortcut.privacy,
    ),
  ];

  static List<UnitBranch> forUnit(String unitId) {
    switch (unitId) {
      case 'doctors':
        return _doctors;
      case 'patients':
        return _patients;
      case 'labs':
        return _labs;
      case 'radiology':
        return _radiology;
      case 'pharmacy':
        return _pharmacy;
      case 'hospital':
        return _hospital;
      case 'dental':
        return _dental;
      case 'women':
        return _women;
      case 'donations':
        return _donations;
      case 'education':
        return _education;
      case 'chronicPlans':
        return _chronic;
      case 'medicalDevices':
        return _devices;
      case 'biometrics':
        return _biometrics;
      case 'connectedDevices':
        return _connected;
      default:
        return const [];
    }
  }

  static const _doctors = [
    UnitBranch(
      id: 'publicCv',
      titleAr: 'الملف العام للطبيب',
      subtitleAr:
          'منظومة Lifex-AI للخدمات الصحية العالمية. '
          'الاختصاص والمكان يكتبهما صاحب الحساب',
      icon: Icons.badge_outlined,
      storageKey: BoxKeys.doctors,
      primaryLabelAr: 'اسم الطبيب أو العيادة',
      detailLabelAr: 'الاختصاص والمكان',
      extraFields: [
        UnitBranchField(key: 'hours', labelAr: 'أوقات الدوام'),
        UnitBranchField(key: 'languages', labelAr: 'اللغات'),
        UnitBranchField(key: 'services', labelAr: 'الخدمات', maxLines: 2),
        UnitBranchField(key: 'license', labelAr: 'الترخيص والدولة'),
        UnitBranchField(key: 'contact', labelAr: 'رقم التواصل أو البريد'),
        UnitBranchField(key: 'note', labelAr: 'ملاحظة اختيارية'),
      ],
      needsServer: true,
    ),
    UnitBranch(
      id: 'interested',
      titleAr: 'مهتم',
      subtitleAr: 'متابعة أخبار دون علاقة طبية ودون فتح الملف الصحي',
      icon: Icons.visibility_outlined,
      storageKey: BoxKeys.doctorInterested,
      primaryLabelAr: 'اسم الطبيب',
      detailLabelAr: 'ملاحظة المتابعة',
    ),
    UnitBranch(
      id: 'myDoctor',
      titleAr: 'طبيبي',
      subtitleAr: 'علاقة طبية. الوصول للملف حسب صلاحياتك',
      icon: Icons.medical_information_outlined,
      storageKey: BoxKeys.doctorMyDoctors,
      primaryLabelAr: 'اسم الطبيب المعتمد',
      detailLabelAr: 'الصلاحية أو الملاحظة',
      needsServer: true,
    ),
    UnitBranch(
      id: 'directory',
      titleAr: 'دليل الأطباء المحلي',
      subtitleAr: 'اختصاص ثم الأقرب بمسافة تدخلها أنت',
      icon: Icons.place_outlined,
      shortcut: UnitShortcut.doctorDirectory,
    ),
    UnitBranch(
      id: 'book',
      titleAr: 'الحجز والأكواد',
      subtitleAr: 'مسودة على الجهاز. التأكيد لدى العيادة يحتاج خادماً',
      icon: Icons.qr_code_2,
      shortcut: UnitShortcut.bookings,
      needsServer: true,
    ),
    UnitBranch(
      id: 'follow',
      titleAr: 'المتابعة بعد المعاينة',
      subtitleAr: 'زيارات وأسئلة للطبيب من ملفك',
      icon: Icons.event_repeat_outlined,
      storageKey: 'doctorFollowUpRecords',
      primaryLabelAr: 'الموضوع',
      detailLabelAr: 'ما قاله الطبيب أو موعد العودة',
    ),
    UnitBranch(
      id: 'diary',
      titleAr: 'يوميات الطبيب',
      subtitleAr: 'حصص اليوم بلا مرضى وهميين. أولوية همم ظاهرة',
      icon: Icons.event_note_outlined,
      shortcut: UnitShortcut.doctorDiary,
    ),
  ];

  static const _patients = [
    UnitBranch(
      id: 'careRole',
      titleAr: 'دور الرعاية',
      subtitleAr: 'سجلات محلية دون كشف ملفات الآخرين',
      icon: Icons.personal_injury_outlined,
      storageKey: BoxKeys.patients,
      primaryLabelAr: 'الاسم المستعار أو الدور',
      detailLabelAr: 'ملاحظة رعاية',
      needsServer: true,
    ),
    UnitBranch(
      id: 'visits',
      titleAr: 'الزيارات',
      subtitleAr: 'زيارات سجّلتها أنت لهذا الجهاز',
      icon: Icons.event_outlined,
      storageKey: 'patientVisitRecords',
      primaryLabelAr: 'الجهة أو القسم',
      detailLabelAr: 'السبب أو النتيجة',
    ),
    UnitBranch(
      id: 'familyLink',
      titleAr: 'ربط العائلة',
      subtitleAr: 'ملفات مستقلة تحت الحساب',
      icon: Icons.family_restroom_outlined,
      shortcut: UnitShortcut.family,
    ),
  ];

  static const _labs = [
    UnitBranch(
      id: 'publicLab',
      titleAr: 'الملف العام للمخبر',
      subtitleAr:
          'منظومة Lifex-AI للخدمات الصحية العالمية. '
          'الاسم والمكان يكتبهما صاحب الحساب. بلا نتائج مرضى',
      icon: Icons.storefront_outlined,
      storageKey: BoxKeys.labs,
      primaryLabelAr: 'اسم المخبر',
      detailLabelAr: 'العنوان أو الأنواع',
      extraFields: [
        UnitBranchField(key: 'hours', labelAr: 'أوقات العمل'),
        UnitBranchField(key: 'contact', labelAr: 'التواصل'),
        UnitBranchField(key: 'license', labelAr: 'الترخيص والدولة'),
        UnitBranchField(key: 'place', labelAr: 'المدينة أو المسافة'),
        UnitBranchField(key: 'research', labelAr: 'ملاحظة تجربة بحثية'),
        UnitBranchField(key: 'sendingDoctor', labelAr: 'الطبيب المرسل إن وُجد'),
      ],
      needsServer: true,
    ),
    UnitBranch(
      id: 'types',
      titleAr: 'أنواع المخابر',
      subtitleAr: 'كيميائي، جرثومي، دم، هرمونات، مناعة، وراثة، فيروسات',
      icon: Icons.category_outlined,
      storageKey: 'labTypeRecords',
      primaryLabelAr: 'نوع المخبر',
      detailLabelAr: 'التحاليل المتوفرة كما تعرفها',
    ),
    UnitBranch(
      id: 'requests',
      titleAr: 'طلبات التحاليل',
      subtitleAr: 'طلب ثم نتيجة للطبيب. ليست قراءة آلية',
      icon: Icons.science_outlined,
      shortcut: UnitShortcut.labOrders,
    ),
    UnitBranch(
      id: 'samples',
      titleAr: 'العينات',
      subtitleAr: 'تتبع يدوي لحالة العينة على جهازك',
      icon: Icons.opacity_outlined,
      storageKey: BoxKeys.labSamples,
      primaryLabelAr: 'نوع العينة',
      extraFields: [
        UnitBranchField(key: 'stage', labelAr: 'المرحلة: سحب / تحليل / جاهز'),
      ],
      detailLabelAr: 'المخبر أو الرقم',
    ),
    UnitBranch(
      id: 'book',
      titleAr: 'حجز تحليل',
      subtitleAr: 'رمز محلي للعرض اليدوي',
      icon: Icons.qr_code_2,
      shortcut: UnitShortcut.bookings,
      needsServer: true,
    ),
    UnitBranch(
      id: 'urineNote',
      titleAr: 'ملاحظة لون البول',
      subtitleAr: 'ملاحظات مظهر تكتبها أنت. ليست نتيجة تحليل ولا قراءة من الكاميرا',
      icon: Icons.opacity_outlined,
      shortcut: UnitShortcut.manualVitals,
    ),
  ];

  static const _radiology = [
    UnitBranch(
      id: 'publicImg',
      titleAr: 'الملف العام لمركز التصوير',
      subtitleAr: 'الأجهزة والخدمات الظاهرة للعامة بلا صور مرضى',
      icon: Icons.apartment_outlined,
      storageKey: BoxKeys.radiology,
      primaryLabelAr: 'اسم المركز',
      detailLabelAr: 'العنوان أو الملاحظة',
      extraFields: [
        UnitBranchField(key: 'hours', labelAr: 'أوقات العمل'),
        UnitBranchField(key: 'license', labelAr: 'الترخيص والدولة'),
        UnitBranchField(key: 'contact', labelAr: 'التواصل أو البريد'),
      ],
      needsServer: true,
    ),
    UnitBranch(
      id: 'modalities',
      titleAr: 'أنواع التصوير',
      subtitleAr: 'X-Ray، CT، MRI، إيكو، ثدي، أسنان — أرشيف شخصي',
      icon: Icons.category_outlined,
      storageKey: BoxKeys.imagingModalities,
      primaryLabelAr: 'نوع الجهاز أو الفحص',
      detailLabelAr: 'المركز أو التاريخ',
    ),
    UnitBranch(
      id: 'requests',
      titleAr: 'طلبات الأشعة',
      subtitleAr: 'أرشيف على نفس الخيط. التفسير للطبيب',
      icon: Icons.radar_outlined,
      shortcut: UnitShortcut.imagingOrders,
    ),
    UnitBranch(
      id: 'camera',
      titleAr: 'أوراق وتقارير مصوّرة',
      subtitleAr: 'بموافقة. بلا قراءة آلية حتى محرك معتمد',
      icon: Icons.camera_alt_outlined,
      shortcut: UnitShortcut.cameraNotes,
    ),
    UnitBranch(
      id: 'liveSight',
      titleAr: 'البث الحي للعدسة',
      subtitleAr: 'على هذه الشاشة فقط. بلا وصف مختلق',
      icon: Icons.videocam_outlined,
      shortcut: UnitShortcut.liveSight,
    ),
    UnitBranch(
      id: 'layeredLens',
      titleAr: 'تقريب العدسة',
      subtitleAr: 'معاينة حية وزوم العتاد. ليست تشخيص جلد',
      icon: Icons.filter_none_outlined,
      shortcut: UnitShortcut.layeredLens,
    ),
    UnitBranch(
      id: 'thumbnail',
      titleAr: 'إدارة الصورة المصغّرة',
      subtitleAr: 'إدارة الصورة المصغّرة للملف والأوراق',
      icon: Icons.image_outlined,
      shortcut: UnitShortcut.thumbnail,
    ),
    UnitBranch(
      id: 'book',
      titleAr: 'حجز تصوير',
      subtitleAr: 'مسودة محلية',
      icon: Icons.qr_code_2,
      shortcut: UnitShortcut.bookings,
      needsServer: true,
    ),
  ];

  static const _pharmacy = [
    UnitBranch(
      id: 'publicPharm',
      titleAr: 'الملف العام للصيدلية',
      subtitleAr:
          'اتحاد الصيادلة العالمي الإلكتروني عبر منظومة Lifex-AI. '
          'الاسم والمكان والدوام. بلا أرباح أو مخزون داخلي',
      icon: Icons.storefront_outlined,
      storageKey: BoxKeys.pharmacy,
      primaryLabelAr: 'اسم الصيدلية أو الصيدلاني',
      detailLabelAr: 'العنوان أو الخدمة',
      extraFields: [
        UnitBranchField(key: 'hours', labelAr: 'أوقات العمل'),
        UnitBranchField(key: 'availability', labelAr: 'توفر دواء تتابعه'),
        UnitBranchField(key: 'license', labelAr: 'الترخيص والدولة'),
        UnitBranchField(key: 'shifts', labelAr: 'مناوبات أو عطل'),
        UnitBranchField(key: 'shipping', labelAr: 'ملاحظة الشحن للعموم'),
        UnitBranchField(key: 'contact', labelAr: 'البريد أو رقم التواصل'),
        UnitBranchField(key: 'note', labelAr: 'ملاحظة اختيارية'),
      ],
      needsServer: true,
    ),
    UnitBranch(
      id: 'stock',
      titleAr: 'المخزون المحلي',
      subtitleAr: 'كميات على هذا الجهاز ثم أقرب صنف بالمدينة المدخلة',
      icon: Icons.inventory_2_outlined,
      shortcut: UnitShortcut.pharmacyStock,
    ),
    UnitBranch(
      id: 'rx',
      titleAr: 'الوصفات',
      subtitleAr: 'مرتبطة بسجل أدويتك. لا بيع دم',
      icon: Icons.receipt_long_outlined,
      storageKey: 'pharmacyPrescriptionRecords',
      primaryLabelAr: 'الدواء أو الوصفة',
      detailLabelAr: 'الصيدلية أو الحالة',
    ),
    UnitBranch(
      id: 'meds',
      titleAr: 'أدويتي',
      subtitleAr: 'الجرعة من وصفة الطبيب والتداخلات المرجعية',
      icon: Icons.medication_outlined,
      shortcut: UnitShortcut.medications,
    ),
    UnitBranch(
      id: 'catalog',
      titleAr: 'دليل الأدوية المرجعي',
      subtitleAr: 'أسماء وتصنيفات للبحث وليست وصفة',
      icon: Icons.menu_book_outlined,
      shortcut: UnitShortcut.medicalReferenceDrugs,
    ),
  ];

  static const _hospital = [
    UnitBranch(
      id: 'publicHosp',
      titleAr: 'الملف العام للمستشفى',
      subtitleAr:
          'منظومة Lifex-AI للخدمات الصحية العالمية. '
          'الأقسام والخدمات يكتبها صاحب الحساب. بلا ملفات مرضى',
      icon: Icons.local_hospital_outlined,
      storageKey: BoxKeys.hospital,
      primaryLabelAr: 'اسم المستشفى',
      detailLabelAr: 'العنوان أو الخدمة',
      extraFields: [
        UnitBranchField(key: 'emergency', labelAr: 'قسم الطوارئ'),
        UnitBranchField(key: 'hours', labelAr: 'أوقات العمل'),
        UnitBranchField(key: 'ambulance', labelAr: 'رقم الإسعاف كما تعرفه'),
        UnitBranchField(key: 'place', labelAr: 'المدينة أو المسافة'),
        UnitBranchField(key: 'staffNote', labelAr: 'ملاحظة الطاقم'),
        UnitBranchField(key: 'achievement', labelAr: 'إنجاز يكتبه صاحب الحساب'),
        UnitBranchField(key: 'freeServices', labelAr: 'خدمات مجانية ظاهرة'),
        UnitBranchField(key: 'paidServices', labelAr: 'خدمات مأجورة ظاهرة'),
      ],
      needsServer: true,
    ),
    UnitBranch(
      id: 'departments',
      titleAr: 'الأقسام',
      subtitleAr: 'قلب، أطفال، عناية، نساء… سجل محلي',
      icon: Icons.account_tree_outlined,
      storageKey: BoxKeys.hospitalDepartments,
      primaryLabelAr: 'اسم القسم',
      detailLabelAr: 'ملاحظة أو طبيب القسم',
    ),
    UnitBranch(
      id: 'admit',
      titleAr: 'الدخول',
      subtitleAr: 'استقبال ودخول تسجّله أنت',
      icon: Icons.login_outlined,
      storageKey: BoxKeys.hospitalAdmissions,
      primaryLabelAr: 'القسم أو السبب',
      detailLabelAr: 'التاريخ أو الملاحظة',
    ),
    UnitBranch(
      id: 'discharge',
      titleAr: 'الخروج والمتابعة',
      subtitleAr: 'تعليمات بعد الخروج من تقرير الطبيب',
      icon: Icons.logout_outlined,
      storageKey: BoxKeys.hospitalDischarge,
      primaryLabelAr: 'ملخص الخروج',
      detailLabelAr: 'المتابعة المطلوبة',
    ),
    UnitBranch(
      id: 'labs',
      titleAr: 'مخابر المستشفى',
      subtitleAr: 'طلبات مرتبطة بنفس الملف',
      icon: Icons.science_outlined,
      shortcut: UnitShortcut.labOrders,
    ),
    UnitBranch(
      id: 'imaging',
      titleAr: 'أشعة المستشفى',
      subtitleAr: 'نفس خيط الأرشيف',
      icon: Icons.radar_outlined,
      shortcut: UnitShortcut.imagingOrders,
    ),
    UnitBranch(
      id: 'pharmacy',
      titleAr: 'صيدلية المستشفى',
      subtitleAr: 'مخزون محلي وليس بيعاً',
      icon: Icons.local_pharmacy_outlined,
      shortcut: UnitShortcut.pharmacyStock,
    ),
    UnitBranch(
      id: 'blood',
      titleAr: 'طلب دم داخل المستشفى',
      subtitleAr: 'للموافقين على هذا الجهاز فقط',
      icon: Icons.bloodtype_outlined,
      shortcut: UnitShortcut.bloodNetwork,
    ),
    UnitBranch(
      id: 'book',
      titleAr: 'الحجز والأكواد',
      subtitleAr: 'رقم دور بلا أسماء على الشاشة العامة',
      icon: Icons.qr_code_2,
      shortcut: UnitShortcut.bookings,
      needsServer: true,
    ),
    UnitBranch(
      id: 'board',
      titleAr: 'لوحة داخلية وشاشة عامة',
      subtitleAr: 'من سجلات هذا الجهاز. لوحة المستشفى الكاملة تحتاج خادماً',
      icon: Icons.dashboard_outlined,
      shortcut: UnitShortcut.world,
      needsServer: true,
    ),
  ];

  static const _dental = [
    UnitBranch(
      id: 'publicDental',
      titleAr: 'الملف العام للعيادة',
      subtitleAr:
          'منظومة Lifex-AI للخدمات الصحية العالمية. '
          'الاختصاص والمكان يكتبهما صاحب الحساب. بلا خطة علاج للآخرين',
      icon: Icons.storefront_outlined,
      storageKey: BoxKeys.dental,
      primaryLabelAr: 'اسم الطبيب أو المركز',
      detailLabelAr: 'الاختصاص أو العنوان',
      extraFields: [
        UnitBranchField(key: 'specialty', labelAr: 'تقويم / جذور / أطفال / زراعة…'),
        UnitBranchField(key: 'license', labelAr: 'الترخيص والدولة'),
        UnitBranchField(key: 'place', labelAr: 'المدينة أو المسافة'),
        UnitBranchField(key: 'labNote', labelAr: 'ملاحظة المخبر السني'),
        UnitBranchField(key: 'contact', labelAr: 'التواصل'),
      ],
      needsServer: true,
    ),
    UnitBranch(
      id: 'chart',
      titleAr: 'مخطط الأسنان FDI',
      subtitleAr: 'ملاحظة على كل سن',
      icon: Icons.tag_outlined,
      shortcut: UnitShortcut.dentalChart,
    ),
    UnitBranch(
      id: 'plan',
      titleAr: 'خطة العلاج',
      subtitleAr: 'إجراءات مرتبطة بالطبيب والمخبر',
      icon: Icons.checklist_outlined,
      storageKey: 'dentalPlanRecords',
      primaryLabelAr: 'الإجراء',
      detailLabelAr: 'الخطة أو الموعد',
    ),
    UnitBranch(
      id: 'book',
      titleAr: 'حجز سني',
      subtitleAr: 'مسودة محلية',
      icon: Icons.qr_code_2,
      shortcut: UnitShortcut.bookings,
      needsServer: true,
    ),
  ];

  static const _women = [
    UnitBranch(
      id: 'edu',
      titleAr: 'التثقيف الصحي',
      subtitleAr: 'معرفة عامة: تغذية، وقاية، فحوص، نفس. ليست تشخيصاً',
      icon: Icons.menu_book_outlined,
      storageKey: 'womenEducationNotes',
      primaryLabelAr: 'الموضوع',
      detailLabelAr: 'ما تريدين تذكّره',
    ),
    UnitBranch(
      id: 'womenArcade',
      titleAr: 'رواق المعرفة',
      subtitleAr: 'مكتبة الأسرة واليافعين ورفّ التحميل',
      icon: Icons.account_balance_outlined,
      shortcut: UnitShortcut.knowledgeArcade,
    ),
    UnitBranch(
      id: 'womenChildRights',
      titleAr: 'كتاب حقوق الطفل',
      subtitleAr: 'قراءة محلية من رواق المعرفة',
      icon: Icons.child_care_outlined,
      shortcut: UnitShortcut.childRightsBook,
    ),
    UnitBranch(
      id: 'pre',
      titleAr: 'التخطيط للحمل',
      subtitleAr: 'استعداد وفحوص حسب موافقة الطرفين',
      icon: Icons.favorite_outline,
      storageKey: 'womenPrePregnancy',
      primaryLabelAr: 'البند',
      detailLabelAr: 'الملاحظة',
    ),
    UnitBranch(
      id: 'preg',
      titleAr: 'ملف الحمل',
      subtitleAr: 'بداية الحمل، زيارات، تحاليل كما سجلها الطبيب',
      icon: Icons.pregnant_woman_outlined,
      storageKey: BoxKeys.women,
      primaryLabelAr: 'المرحلة أو الزيارة',
      extraFields: [
        UnitBranchField(key: 'week', labelAr: 'أسبوع الحمل إن عُرف'),
      ],
      detailLabelAr: 'ملاحظة صحية',
    ),
    UnitBranch(
      id: 'questions',
      titleAr: 'أسئلة للطبيبة',
      subtitleAr: 'تجهيز أسئلة الموعد. ليست إجابة طبية من التطبيق',
      icon: Icons.quiz_outlined,
      storageKey: 'womenDoctorQuestions',
      primaryLabelAr: 'السؤال',
      detailLabelAr: 'سياق الموعد',
    ),
    UnitBranch(
      id: 'birth',
      titleAr: 'خطة الولادة',
      subtitleAr: 'رغبات ومتابعة مع المستشفى والطبيب',
      icon: Icons.child_care_outlined,
      storageKey: 'womenBirthPlan',
      primaryLabelAr: 'البند',
      detailLabelAr: 'التفضيل أو الملاحظة',
    ),
    UnitBranch(
      id: 'post',
      titleAr: 'ما بعد الولادة',
      subtitleAr: 'نفاس ورضاعة ومزاج بلطف دون تشخيص',
      icon: Icons.spa_outlined,
      storageKey: 'womenPostpartumLogs',
      primaryLabelAr: 'اليوم أو الموضوع',
      extraFields: [
        UnitBranchField(key: 'feeding', labelAr: 'الرضاعة إن رغبت'),
        UnitBranchField(key: 'support', labelAr: 'وجود دعم في المنزل'),
      ],
      detailLabelAr: 'الملاحظة',
    ),
    UnitBranch(
      id: 'cycle',
      titleAr: 'الدورة والحمل في وحدة الإناث',
      subtitleAr: 'تواريخكِ، رسالة خاصة، زر الحمل. ليست إعلاناً اجتماعياً',
      icon: Icons.calendar_today_outlined,
      shortcut: UnitShortcut.womenCycle,
    ),
    UnitBranch(
      id: 'labs',
      titleAr: 'تحاليل الحمل',
      subtitleAr: 'نفس مسار المخبر',
      icon: Icons.science_outlined,
      shortcut: UnitShortcut.labOrders,
    ),
    UnitBranch(
      id: 'privacy',
      titleAr: 'خصوصية القضايا الحساسة',
      subtitleAr: 'من يرى بيانات المرأة في الملف',
      icon: Icons.lock_outline,
      shortcut: UnitShortcut.privacy,
    ),
  ];

  static const _donations = [
    UnitBranch(
      id: 'individual',
      titleAr: 'تبرع لحالة',
      subtitleAr: 'مالي أو علاجي. التحويل يحتاج مفاتيح دفع حقيقية',
      icon: Icons.volunteer_activism_outlined,
      storageKey: BoxKeys.donations,
      primaryLabelAr: 'الحالة أو الشخص',
      extraFields: [
        UnitBranchField(key: 'kind', labelAr: 'مالي / دواء / جهاز / فحص'),
      ],
      detailLabelAr: 'التفاصيل',
      needsServer: true,
    ),
    UnitBranch(
      id: 'inKind',
      titleAr: 'تبرع عيني أو خدمي',
      subtitleAr: 'أدوية، أجهزة، معاينة مخفّضة — بلا شبكة وهمية',
      icon: Icons.handshake_outlined,
      storageKey: BoxKeys.donationKinds,
      primaryLabelAr: 'نوع الدعم',
      detailLabelAr: 'الجهة أو الملاحظة',
      needsServer: true,
    ),
    UnitBranch(
      id: 'blood',
      titleAr: 'شبكة الدم',
      subtitleAr: 'سبع مراحل للموافقين فقط. بلا بيع دم',
      icon: Icons.bloodtype_outlined,
      shortcut: UnitShortcut.bloodNetwork,
    ),
    UnitBranch(
      id: 'wallet',
      titleAr: 'المحفظة',
      subtitleAr: 'تتبع تبرع مالي عند وجود مفاتيح حقيقية',
      icon: Icons.account_balance_wallet_outlined,
      shortcut: UnitShortcut.wallet,
      needsServer: true,
    ),
  ];

  static const _education = [
    UnitBranch(
      id: 'courses',
      titleAr: 'الدورات',
      subtitleAr: 'برامج تسجّلها أنت. ليست منصة خارجية ناجحة',
      icon: Icons.school_outlined,
      storageKey: BoxKeys.education,
      primaryLabelAr: 'اسم الدورة',
      extraFields: [
        UnitBranchField(key: 'level', labelAr: 'المستوى'),
      ],
      detailLabelAr: 'التقدم أو الموعد',
    ),
    UnitBranch(
      id: 'plan',
      titleAr: 'خطة التطوير الشخصية',
      subtitleAr: 'ماذا تحتاج أن تتعلم — بتصريحك',
      icon: Icons.flag_outlined,
      storageKey: BoxKeys.educationPlan,
      primaryLabelAr: 'الهدف',
      detailLabelAr: 'المهارة أو الخطوة التالية',
    ),
    UnitBranch(
      id: 'certs',
      titleAr: 'الشهادات',
      subtitleAr: 'سجل شخصي وليس تحققاً جامعياً',
      icon: Icons.workspace_premium_outlined,
      storageKey: 'educationCertificateRecords',
      primaryLabelAr: 'اسم الشهادة',
      detailLabelAr: 'الجهة أو السنة',
    ),
    UnitBranch(
      id: 'empower',
      titleAr: 'موسوعة التمكين',
      subtitleAr: 'فصول واستماع وميثاق محلي. ليست استشارة مالية',
      icon: Icons.menu_book_outlined,
      shortcut: UnitShortcut.empowermentLab,
    ),
    UnitBranch(
      id: 'arcade',
      titleAr: 'رواق المعرفة',
      subtitleAr: 'مكتبات للقراءة ورفّ تنزيل إلى الجهاز',
      icon: Icons.account_balance_outlined,
      shortcut: UnitShortcut.knowledgeArcade,
    ),
    UnitBranch(
      id: 'childRights',
      titleAr: 'كتاب حقوق الطفل',
      subtitleAr: 'قراءة محلية. ليس قانون دولة',
      icon: Icons.child_care_outlined,
      shortcut: UnitShortcut.childRightsBook,
    ),
    UnitBranch(
      id: 'choiceMirror',
      titleAr: 'مَرآةُ الاختيار',
      subtitleAr: 'عرض تلقائي بالعربية أو الإنجليزية المستخدمة',
      icon: Icons.favorite_outline,
      shortcut: UnitShortcut.choiceMirror,
    ),
    UnitBranch(
      id: 'youthGuide',
      titleAr: 'دليل اليافعين',
      subtitleAr: 'من وعي الذات إلى خطوة الغد',
      icon: Icons.auto_stories_outlined,
      shortcut: UnitShortcut.youthGuide,
    ),
    UnitBranch(
      id: 'royalQuiz',
      titleAr: 'المنصة الملكية',
      subtitleAr: 'تمرين أنماط. ليس مقياس ذكاء سريري',
      icon: Icons.psychology_outlined,
      shortcut: UnitShortcut.royalIntelligence,
    ),
    UnitBranch(
      id: 'personalShelf',
      titleAr: 'رفّ التحميل الشخصي',
      subtitleAr: 'نزّل كتاباً نصياً أو احذفه',
      icon: Icons.download_outlined,
      shortcut: UnitShortcut.personalShelf,
    ),
  ];

  static const _chronic = [
    UnitBranch(
      id: 'plans',
      titleAr: 'الخطط طويلة الأمد',
      subtitleAr: 'علاج مزمن أو مستعصٍ كما كتبه الطبيب',
      icon: Icons.accessibility_new_outlined,
      storageKey: BoxKeys.chronicPlans,
      primaryLabelAr: 'الحالة أو الخطة',
      extraFields: [
        UnitBranchField(key: 'remind', labelAr: 'تذكير دوري'),
      ],
      detailLabelAr: 'المتابعة',
    ),
    UnitBranch(
      id: 'disability',
      titleAr: 'تثبيت المعاقين والمرضى الدائمين',
      subtitleAr:
          'بطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه صاحب الحساب',
      icon: Icons.accessible_outlined,
      shortcut: UnitShortcut.disabilityFixation,
      storageKey: BoxKeys.disabilityRecords,
      primaryLabelAr: 'حركية، سمعية، بصرية، عقلية، متعددة، أخرى',
    ),
    UnitBranch(
      id: 'access',
      titleAr: 'مساعدة المكفوفين',
      subtitleAr: 'وصف مشهد وقراءة. بلا نتيجة وهمية قبل المحرك',
      icon: Icons.visibility_outlined,
      shortcut: UnitShortcut.accessibility,
    ),
    UnitBranch(
      id: 'liveSightChronic',
      titleAr: 'عدسة حية للمكفوفين',
      subtitleAr: 'نبض إطار مع نطق صادق إن غاب المحرك',
      icon: Icons.videocam_outlined,
      shortcut: UnitShortcut.liveSight,
    ),
    UnitBranch(
      id: 'radar',
      titleAr: 'الرادار الضوئي',
      subtitleAr: 'مسافة فقط إن وُجد حسّاس زمن رحلة',
      icon: Icons.radar_outlined,
      shortcut: UnitShortcut.opticalRadar,
    ),
    UnitBranch(
      id: 'remote',
      titleAr: 'المراقبة عن بعد',
      subtitleAr: 'أربعة مستويات صلاحية. الحية تحتاج إذناً وخادماً',
      icon: Icons.shield_outlined,
      shortcut: UnitShortcut.protection,
    ),
  ];

  static const _devices = [
    UnitBranch(
      id: 'registry',
      titleAr: 'سجل الأجهزة',
      subtitleAr: 'ضغط، سكر، أكسجين… بلا بلوتوث مزيف',
      icon: Icons.monitor_heart_outlined,
      storageKey: BoxKeys.medicalDevices,
      primaryLabelAr: 'نوع الجهاز',
      extraFields: [
        UnitBranchField(key: 'maker', labelAr: 'الشركة'),
        UnitBranchField(key: 'protocol', labelAr: 'بلوتوث / واي فاي / يدوي'),
      ],
      detailLabelAr: 'ملاحظة المعايرة',
      needsServer: true,
    ),
    UnitBranch(
      id: 'clinicalWatch',
      titleAr: 'مراقبة سريرية ظاهرة',
      subtitleAr: 'إشعار دائم بموافقة. بلا تصوير خفي وبلا حفظ صور',
      icon: Icons.monitor_heart_outlined,
      shortcut: UnitShortcut.clinicalWatch,
    ),
    UnitBranch(
      id: 'readings',
      titleAr: 'قراءات يدوية',
      subtitleAr: 'من جهازك أو طبيبك. ليست من الكاميرا',
      icon: Icons.favorite_outline,
      shortcut: UnitShortcut.manualVitals,
    ),
  ];

  static const _biometrics = [
    UnitBranch(
      id: 'panel',
      titleAr: 'لوحة القياسات اليدوية',
      subtitleAr: 'حرارة وأكسجين ونبض من جهازك. بلا صورة وبلا قيم مخترعة',
      icon: Icons.monitor_heart_outlined,
      shortcut: UnitShortcut.manualVitals,
    ),
    UnitBranch(
      id: 'heart',
      titleAr: 'القلب',
      subtitleAr: 'نبض وانتظام كما قِيس خارج التطبيق',
      icon: Icons.favorite_outline,
      storageKey: 'bioHeartLogs',
      primaryLabelAr: 'النبض أو الانتظام',
      detailLabelAr: 'القيمة والمصدر',
    ),
    UnitBranch(
      id: 'breath',
      titleAr: 'التنفس',
      subtitleAr: 'المعدل والتغيرات يدويًا',
      icon: Icons.air,
      storageKey: 'bioBreathLogs',
      primaryLabelAr: 'المعدل',
      detailLabelAr: 'المصدر',
    ),
    UnitBranch(
      id: 'body',
      titleAr: 'الجسم',
      subtitleAr: 'حرارة، حركة، سقوط، نشاط',
      icon: Icons.thermostat_outlined,
      storageKey: 'bioBodyLogs',
      primaryLabelAr: 'النوع',
      detailLabelAr: 'القيمة',
    ),
    UnitBranch(
      id: 'clinical',
      titleAr: 'قياسات سريرية',
      subtitleAr: 'ضغط، سكر، أكسجين، وزن',
      icon: Icons.monitor_heart_outlined,
      storageKey: BoxKeys.biometrics,
      primaryLabelAr: 'نوع القياس',
      extraFields: [
        UnitBranchField(key: 'source', labelAr: 'الجهاز أو الطبيب'),
      ],
      detailLabelAr: 'القيمة',
    ),
  ];

  static const _connected = [
    UnitBranch(
      id: 'phones',
      titleAr: 'الهواتف والشاشات',
      subtitleAr: 'أجهزة يصرّح بها المستخدم على هذا الحساب',
      icon: Icons.devices_outlined,
      storageKey: BoxKeys.connectedDevices,
      primaryLabelAr: 'اسم الجهاز',
      extraFields: [
        UnitBranchField(key: 'channel', labelAr: 'النوع أو القناة'),
      ],
      detailLabelAr: 'ملاحظة',
      needsServer: true,
    ),
    UnitBranch(
      id: 'remote',
      titleAr: 'أوامر عن بعد',
      subtitleAr: 'تشغيل كاميرا أو قراءة حسّاس يحتاج خادماً',
      icon: Icons.settings_remote_outlined,
      storageKey: 'remoteCommandLog',
      primaryLabelAr: 'الأمر المطلوب',
      detailLabelAr: 'الجهاز المستهدف — يبقى محلياً حتى يوجد خادم',
      needsServer: true,
    ),
    UnitBranch(
      id: 'guardian',
      titleAr: 'حارس الجهاز',
      subtitleAr: 'فقدان محلي بلا Device Admin',
      icon: Icons.phonelink_erase_outlined,
      shortcut: UnitShortcut.protection,
    ),
  ];
}
