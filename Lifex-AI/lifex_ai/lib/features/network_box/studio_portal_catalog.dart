/// =============================================================
/// Lifex-AI — شاشات استوديو الشبكة
/// أسماء البوابات من المستودع google-studio. كل اسم يفتح المقعد المحلي.
/// بيانات العرض الوهمية في الويب ليست قراءات ولا تشخيصاً.
/// =============================================================
library lifex_ai.features.network_box.studio_portal_catalog;

enum StudioPortalId {
  patient,
  doctor,
  hospital,
  lab,
  pharmacy,
  privacy,
  admin,
  emergency,
  womenHealth,
  devices,
  ai,
  network,
  organizations,
}

class StudioPortal {
  const StudioPortal({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
  });

  final StudioPortalId id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;

  String title(bool arabic) => arabic ? titleAr : titleEn;

  String subtitle(bool arabic) => arabic ? subtitleAr : subtitleEn;
}

class StudioPortalCatalog {
  const StudioPortalCatalog._();

  static const sourceRepo = 'g0955531388-collab/google-studio';

  static const ownershipAr =
      'Lifex-AI — الملكية والشراكة مناصفة: غازي سليم بكفلاوي ورباب الحايك | المخترع: غازي سليم بكفلاوي';

  static const ownershipEn =
      'Lifex-AI — Equal ownership and partnership: Ghazi Salim Bekfalawi and Rabab Al-Hayek | Inventor: Ghazi Salim Bekfalawi';

  static const honestyAr = 'هذه بوابات الاستوديو مربوطة بالمقاعد المحلية. '
      'أرقام العرض في نسخة الويب لا تُنسخ إلى هنا، وليست قياساً ولا تشخيصاً.';

  static const honestyEn =
      'These studio portals open the local seats on this device. '
      'Web demo figures are not copied here, and they are not a measurement or a diagnosis.';

  static const disclaimerBarAr =
      'منصة دعم صحي ومعلوماتي وتقني، وليست بديلاً عن الطبيب أو المختص الصحي. '
      'الذكاء الاصطناعي لا يتخذ قرارات سريرية مستقلة.';

  static const disclaimerBarEn =
      'A health, informational, and technical support platform, '
      'not a replacement for a licensed clinician. '
      'AI does not make independent clinical decisions.';

  static const portalsMenuTitle = 'بوابات المنظومة';
  static const portalsMenuTitleEn = 'Network Portals';
  static const portalsMenuHintAr = 'بوابات المنظومة الطبية';
  static const portalsMenuHintEn = 'Medical network portals';

  static const servicesTitleAr = 'البوابات المربوطة على هذا الجهاز';
  static const servicesTitleEn = 'Portals linked on this device';

  static String honesty(bool arabic) => arabic ? honestyAr : honestyEn;

  static String disclaimer(bool arabic) =>
      arabic ? disclaimerBarAr : disclaimerBarEn;

  static String portalsMenu(bool arabic) =>
      arabic ? portalsMenuTitle : portalsMenuTitleEn;

  static String portalsHint(bool arabic) =>
      arabic ? portalsMenuHintAr : portalsMenuHintEn;

  static String servicesTitle(bool arabic) =>
      arabic ? servicesTitleAr : servicesTitleEn;

  static const mainNav = <StudioMenuItem>[
    StudioMenuItem('الرئيسية', titleEn: 'Home'),
    StudioMenuItem(
      'الشبكة الصحية',
      portalId: StudioPortalId.network,
      titleEn: 'Health Network',
    ),
    StudioMenuItem(
      'ذكاء Lifex-AI',
      portalId: StudioPortalId.ai,
      accent: StudioMenuAccent.purple,
      titleEn: 'Lifex-AI Intelligence',
    ),
    StudioMenuItem(
      'الأجهزة الطبية',
      portalId: StudioPortalId.devices,
      titleEn: 'Medical Devices',
    ),
    StudioMenuItem(
      'طوارئ 24/7',
      portalId: StudioPortalId.emergency,
      accent: StudioMenuAccent.rose,
      titleEn: '24/7 Emergency',
    ),
    StudioMenuItem(
      'الخصوصية والأمان',
      portalId: StudioPortalId.privacy,
      titleEn: 'Privacy & Security',
    ),
  ];

  static const portals = <StudioPortal>[
    StudioPortal(
      id: StudioPortalId.network,
      titleAr: 'الشبكة الصحية',
      titleEn: 'Health Network',
      subtitleAr: 'المركز الموحد للمقاعد المحلية',
      subtitleEn: 'Local seats in one place on this device',
    ),
    StudioPortal(
      id: StudioPortalId.patient,
      titleAr: 'بوابة المريض',
      titleEn: 'Patient Portal',
      subtitleAr: 'الملف الذي يملأه صاحب الحساب',
      subtitleEn: 'The record the account holder fills in',
    ),
    StudioPortal(
      id: StudioPortalId.doctor,
      titleAr: 'بوابة الطبيب والعيادة',
      titleEn: 'Doctor Portal',
      subtitleAr: 'دليل محلي. المسافة مما يكتبه صاحب الحساب',
      subtitleEn: 'A local directory. Distance comes from what you enter',
    ),
    StudioPortal(
      id: StudioPortalId.hospital,
      titleAr: 'بوابة المستشفى والمركز الجراحي',
      titleEn: 'Hospital Portal',
      subtitleAr: 'سجل محلي. الربط الخارجي يحتاج جهة',
      subtitleEn: 'A local record. An outside link needs a real party',
    ),
    StudioPortal(
      id: StudioPortalId.lab,
      titleAr: 'بوابة المختبر والتحاليل',
      titleEn: 'Laboratory Portal',
      subtitleAr: 'طلب يكتبه صاحب الحساب. ليس نتيجة مولَّدة',
      subtitleEn: 'An order you write. Not a generated result',
    ),
    StudioPortal(
      id: StudioPortalId.pharmacy,
      titleAr: 'بوابة الصيدلية والدواء',
      titleEn: 'Pharmacy Portal',
      subtitleAr: 'مخزون محلي. Lifex لا يصرف دواء',
      subtitleEn: 'Local stock. Lifex does not dispense medicine',
    ),
    StudioPortal(
      id: StudioPortalId.privacy,
      titleAr: 'مركز الخصوصية والموافقة',
      titleEn: 'Privacy & Consent',
      subtitleAr: 'من يرى الملف على هذا الجهاز',
      subtitleEn: 'Who can see the record on this device',
    ),
    StudioPortal(
      id: StudioPortalId.admin,
      titleAr: 'لوحة الإدارة والتدقيق',
      titleEn: 'Admin & Audit',
      subtitleAr: 'صلاحية تشغيلية بمعرّف مسجّل',
      subtitleEn: 'Operational access for a registered identity',
    ),
    StudioPortal(
      id: StudioPortalId.emergency,
      titleAr: 'مركز الطوارئ والإسعاف',
      titleEn: 'Emergency',
      subtitleAr: 'جهات يكتبها صاحب الحساب. النداء يبقى بتأكيد',
      subtitleEn: 'Contacts you enter. A call still needs your confirmation',
    ),
    StudioPortal(
      id: StudioPortalId.womenHealth,
      titleAr: 'صحة المرأة والرعاية الأسرية',
      titleEn: "Women's Health & Care",
      subtitleAr: 'ما يكتبه صاحب الملف. ليس تقويماً سريرياً مؤكداً',
      subtitleEn:
          'What the record holder writes. Not a confirmed clinical calendar',
    ),
    StudioPortal(
      id: StudioPortalId.devices,
      titleAr: 'إنترنت الأجهزة الطبية',
      titleEn: 'Medical Devices',
      subtitleAr: 'ظهور الجهاز ليس جلسة ولا قراءة',
      subtitleEn: 'Seeing a device is not a session and not a reading',
    ),
    StudioPortal(
      id: StudioPortalId.ai,
      titleAr: 'ذكاء Lifex-AI',
      titleEn: 'Lifex-AI Intelligence',
      subtitleAr: 'أوامر على هذا الجهاز. ليس طبيباً',
      subtitleEn: 'Commands on this device. Not a physician',
    ),
    StudioPortal(
      id: StudioPortalId.organizations,
      titleAr: 'الجهات والمؤسسات الإغاثية',
      titleEn: 'Organizations & Relief',
      subtitleAr: 'مساحة محلية. لا نجاح مؤسسي مخترع',
      subtitleEn: 'A local space. No invented institutional success',
    ),
  ];
}

enum StudioMenuAccent { teal, purple, rose }

class StudioMenuItem {
  const StudioMenuItem(
    this.titleAr, {
    this.portalId,
    this.accent = StudioMenuAccent.teal,
    this.titleEn = '',
  });

  final String titleAr;
  final StudioPortalId? portalId;
  final StudioMenuAccent accent;
  final String titleEn;

  String title(bool arabic) => arabic || titleEn.isEmpty ? titleAr : titleEn;
}
