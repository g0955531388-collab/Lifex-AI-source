/// =============================================================
/// Lifex-AI — الهوية الصحية
/// الملف: health_questionnaire_schema.dart
/// اثنا عشر قسماً من الاستبيان الشامل. صياغة أصلية، ليست نسخ HTML.
/// =============================================================
library lifex_ai.features.profile.health_questionnaire_schema;

enum QuestionKind { text, number, choice, yesNo, photo }

class QuestionField {
  const QuestionField(this.key, this.label, this.kind, {this.options});
  final String key;
  final String label;
  final QuestionKind kind;
  final List<String>? options;
}

class QuestionSection {
  const QuestionSection({
    required this.title,
    required this.spokenOutline,
    required this.fields,
  });
  final String title;
  final String spokenOutline;
  final List<QuestionField> fields;
}

class HealthQuestionnaireSchema {
  HealthQuestionnaireSchema._();

  static const sections = <QuestionSection>[
    QuestionSection(
      title: 'المعلومات الشخصية الأساسية',
      spokenOutline:
          'القسم الأول: الاسم والعمر والجنس والطول والوزن وفصيلة الدم والهاتف والعمل والسكن.',
      fields: [
        QuestionField('surveyNationalId',
            'الرقم الوطني كما في الوثيقة الحقيقية', QuestionKind.text),
        QuestionField('surveyName', 'الاسم كما تريد ظهوره في الاستبيان',
            QuestionKind.text),
        QuestionField('surveyAge', 'العمر بعدد السنوات', QuestionKind.number),
        QuestionField('surveySex', 'الجنس', QuestionKind.choice,
            options: ['ذكر', 'أنثى', 'لا أحدد']),
        QuestionField('heightCm', 'الطول بالسنتيمتر', QuestionKind.number),
        QuestionField('weightKg', 'الوزن بالكيلوغرام', QuestionKind.number),
        QuestionField('surveyBloodType', 'فصيلة الدم', QuestionKind.choice,
            options: [
              'A+',
              'A-',
              'B+',
              'B-',
              'AB+',
              'AB-',
              'O+',
              'O-',
              'غير معروفة',
            ]),
        QuestionField('surveyPhone', 'رقم الهاتف', QuestionKind.text),
        QuestionField('jobStatus', 'الحالة الوظيفية', QuestionKind.text),
        QuestionField('jobNature', 'طبيعة العمل', QuestionKind.choice,
            options: [
              'مكتبي',
              'ميداني',
              'منزلي',
              'مختلط',
              'ورديات',
              'لا يعمل',
            ]),
        QuestionField(
            'workTypeDetail',
            'تفصيل العمل: مواد كيميائية، ضوضاء، إشعاع، رفع أوزان…',
            QuestionKind.text),
        QuestionField('residence', 'مكان السكن', QuestionKind.text),
        QuestionField(
            'economicStatus', 'الحالة الاقتصادية كما تصرّح', QuestionKind.text),
        QuestionField('skinColor', 'لون البشرة', QuestionKind.choice,
            options: ['فاتح', 'قمحي', 'أسمر', 'داكن']),
        QuestionField('eyeColor', 'لون العينين', QuestionKind.choice,
            options: ['بني', 'أسود', 'أزرق', 'أخضر', 'رمادي']),
      ],
    ),
    QuestionSection(
      title: 'التاريخ العائلي والوراثي',
      spokenOutline:
          'القسم الثاني: أفراد العائلة والأمراض الشائعة أو الوراثية.',
      fields: [
        QuestionField(
            'familyMembers', 'أفراد العائلة وصلات القرابة', QuestionKind.text),
        QuestionField('familyDiabetes', 'سكري في العائلة', QuestionKind.yesNo),
        QuestionField(
            'familyHypertension', 'ضغط دم في العائلة', QuestionKind.yesNo),
        QuestionField(
            'familyHeartDisease', 'أمراض قلب في العائلة', QuestionKind.yesNo),
        QuestionField('familyCancer', 'سرطان في العائلة', QuestionKind.yesNo),
        QuestionField('familyGeneticDisease', 'أمراض وراثية في العائلة',
            QuestionKind.yesNo),
        QuestionField(
            'familyNotes', 'أمراض أخرى أو ملاحظات القرابة', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'الحالة الاجتماعية',
      spokenOutline:
          'القسم الثالث: الحالة الاجتماعية وعدد الأبناء والضغوط إن وُجدت.',
      fields: [
        QuestionField('socialStatus', 'الحالة الاجتماعية', QuestionKind.choice,
            options: [
              'أعزب',
              'متزوج',
              'منفصل',
              'مطلق',
              'أرمل',
              'مساكنة',
            ]),
        QuestionField('childrenCount', 'عدد الأبناء', QuestionKind.number),
        QuestionField('socialStress', 'ضغوط أسرية أو اجتماعية إن رغبت بذكرها',
            QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'التاريخ الصحي الشخصي',
      spokenOutline:
          'القسم الرابع: الأمراض الحالية والمزمنة والعارضة المتكررة.',
      fields: [
        QuestionField(
            'hasChronicDisease', 'هل تعاني من مرض مزمن؟', QuestionKind.yesNo),
        QuestionField('chronicDiseaseList', 'الأمراض المزمنة كما كتبها الطبيب',
            QuestionKind.text),
        QuestionField(
            'currentDiseases', 'أمراض أو أعراض حالية', QuestionKind.text),
        QuestionField(
            'recurringInfections', 'أمراض عارضة متكررة', QuestionKind.text),
        QuestionField('previousHospitalization', 'هل دخلت المستشفى سابقاً؟',
            QuestionKind.yesNo),
        QuestionField(
            'medicalHistoryNotes', 'تفاصيل وملاحظات', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'الأدوية والعلاجات',
      spokenOutline:
          'القسم الخامس: الأدوية الحالية والسابقة والعلاجات غير الدوائية والحساسية.',
      fields: [
        QuestionField('usesRegularMedication', 'هل تستخدم أدوية بشكل دائم؟',
            QuestionKind.yesNo),
        QuestionField('medicationList', 'الأدوية الحالية: الاسم والجرعة والمدة',
            QuestionKind.text),
        QuestionField('pastMedications', 'أدوية سابقة مهمة', QuestionKind.text),
        QuestionField('alternativeTreatments',
            'علاجات غير دوائية أو أعشاب أو مكملات', QuestionKind.text),
        QuestionField('hasAllergy', 'هل لديك حساسية؟', QuestionKind.yesNo),
        QuestionField('allergyList', 'المواد التي تسبب الحساسية ورد الفعل',
            QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'عمليات وكسور وزراعة وأجهزة',
      spokenOutline:
          'القسم السادس: عمليات، كسور، إجراءات، زراعة أعضاء، أجهزة مزروعة. الصور من أرشيف الأوراق وليس من هذا الحقل.',
      fields: [
        QuestionField(
            'previousSurgery', 'هل أجريت عملية جراحية؟', QuestionKind.yesNo),
        QuestionField('pastSurgeries', 'العمليات: النوع والتاريخ والمضاعفات',
            QuestionKind.text),
        QuestionField(
            'fractures', 'الكسور السابقة ومكانها وعلاجها', QuestionKind.text),
        QuestionField('procedures',
            'إجراءات أخرى: قسطرة، منظار، خزعة، غسيل كلى…', QuestionKind.text),
        QuestionField(
            'organTransplants', 'زراعة أعضاء إن وُجدت', QuestionKind.text),
        QuestionField(
            'implants', 'أجهزة مزروعة: منظم، دعامة، صمام…', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'صحة المرأة إن انطبق',
      spokenOutline:
          'القسم السابع اختياري: الدورة، الحمل، الولادة، الثدي. إن لم ينطبق اتركه.',
      fields: [
        QuestionField('periodRegularity', 'انتظام الدورة', QuestionKind.choice,
            options: [
              'منتظمة',
              'غير منتظمة',
              'انقطاع',
              'لا ينطبق',
            ]),
        QuestionField(
            'periodProblems', 'مشاكل الدورة إن وُجدت', QuestionKind.text),
        QuestionField('isPregnant', 'حمل حالي', QuestionKind.yesNo),
        QuestionField('pregnancyCount', 'عدد مرات الحمل', QuestionKind.number),
        QuestionField('birthCount', 'عدد الولادات', QuestionKind.number),
        QuestionField('miscarriageCount', 'عدد الإسقاطات كما تصرّحين',
            QuestionKind.number),
        QuestionField('ectopicOrFalsePregnancy',
            'حمل خارج الرحم أو ملاحظة أخرى', QuestionKind.text),
        QuestionField(
            'abnormalHair', 'نمو شعر غير معتاد إن رغبت', QuestionKind.text),
        QuestionField(
            'breastChanges', 'تغيرات الثدي أو تقاريره', QuestionKind.text),
        QuestionField(
            'womenHealthNotes', 'ملاحظات نسائية أخرى', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'أورام وعقد وتصبغات',
      spokenOutline:
          'القسم الثامن: كتل وعقد لمفاوية وتصبغات. الصورة للتوثيق في أرشيف الأوراق وليست تشخيصاً.',
      fields: [
        QuestionField('tumorsOrLumps', 'أورام أو كتل: المكان والحجم وهل تكبر',
            QuestionKind.text),
        QuestionField(
            'lymphNodes', 'عقد لمفاوية: المكان والألم', QuestionKind.text),
        QuestionField(
            'pigmentations', 'تصبغات أو شامات تتغير', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'أجهزة الجسم',
      spokenOutline:
          'القسم التاسع: أعصاب، عين، أذن، أنف، فم، قلب، تنفس، هضم، كبد، كلى، تناسل، عظام، عضلات، جلد، غدد، نفس.',
      fields: [
        QuestionField('nervousSymptoms', 'الجهاز العصبي', QuestionKind.text),
        QuestionField('eyeSymptoms', 'العينان', QuestionKind.text),
        QuestionField('earSymptoms', 'الأذنان', QuestionKind.text),
        QuestionField('noseSymptoms', 'الأنف والجيوب', QuestionKind.text),
        QuestionField(
            'mouthDentalSymptoms', 'الفم والأسنان', QuestionKind.text),
        QuestionField(
            'cardiovascularSymptoms', 'القلب والدورة', QuestionKind.text),
        QuestionField(
            'respiratorySymptoms', 'الجهاز التنفسي', QuestionKind.text),
        QuestionField('digestiveSymptoms', 'الجهاز الهضمي', QuestionKind.text),
        QuestionField('liverSymptoms', 'الكبد والمرارة', QuestionKind.text),
        QuestionField('renalSymptoms', 'الكلى والمسالك', QuestionKind.text),
        QuestionField('genitalSymptoms', 'الجهاز التناسلي', QuestionKind.text),
        QuestionField(
            'musculoskeletalSymptoms', 'العظام والمفاصل', QuestionKind.text),
        QuestionField('muscleSymptoms', 'العضلات', QuestionKind.text),
        QuestionField('skinHairSymptoms', 'الجلد والشعر', QuestionKind.text),
        QuestionField(
            'endocrineSymptoms', 'الغدد والهرمونات', QuestionKind.text),
        QuestionField(
            'mentalSymptoms', 'الصحة النفسية كما تصفها', QuestionKind.text),
        QuestionField('anxiety', 'قلق أو توتر', QuestionKind.yesNo),
        QuestionField('depression', 'مزاج منخفض', QuestionKind.yesNo),
        QuestionField('insomnia', 'أرق', QuestionKind.yesNo),
      ],
    ),
    QuestionSection(
      title: 'نمط الحياة',
      spokenOutline:
          'القسم العاشر: نوم، غذاء، نشاط، تدخين، كحول إن وُجد، بيئة.',
      fields: [
        QuestionField('sleepHours', 'النوم', QuestionKind.choice, options: [
          'أقل من 5 ساعات',
          '5 إلى 7 ساعات',
          'أكثر من 7 ساعات',
        ]),
        QuestionField('sleepQuality', 'جودة النوم', QuestionKind.choice,
            options: [
              'جيدة',
              'متقطعة',
              'سيئة',
              'شخير أو انقطاع نفس',
              'غير معروفة',
            ]),
        QuestionField('dietType', 'نمط الغذاء', QuestionKind.choice, options: [
          'متوازن',
          'غني بالسكر',
          'غني بالدهون',
          'نباتي',
          'غير منتظم',
        ]),
        QuestionField('physicalActivity', 'النشاط البدني', QuestionKind.choice,
            options: [
              'منخفض',
              'متوسط',
              'مرتفع',
            ]),
        QuestionField('smoking', 'هل تدخن؟', QuestionKind.yesNo),
        QuestionField('smokingType', 'نوع التدخين', QuestionKind.choice,
            options: [
              'لا أدخن',
              'سجائر',
              'نرجيلة',
              'إلكتروني',
              'أكثر من نوع',
            ]),
        QuestionField('dailyCigarettes', 'عدد السجائر يومياً إن انطبق',
            QuestionKind.number),
        QuestionField('alcoholNotes', 'الكحول إن وُجد: النوع والتكرار',
            QuestionKind.text),
        QuestionField('environment', 'بيئة المعيشة', QuestionKind.choice,
            options: [
              'مدينة',
              'ريف',
              'رطبة',
              'ملوثة',
              'مختلطة',
            ]),
        QuestionField(
            'lifestyleNotes', 'ملاحظات نمط الحياة', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'الفحوصات والتحاليل',
      spokenOutline:
          'القسم الحادي عشر: آخر تحاليل وصور كما أخبرك الطبيب. الصورة في أرشيف الأوراق.',
      fields: [
        QuestionField('lastBloodTest', 'آخر تحليل دم', QuestionKind.text),
        QuestionField('lastChestXray', 'آخر صورة صدر', QuestionKind.text),
        QuestionField('lastECG', 'آخر تخطيط قلب', QuestionKind.text),
        QuestionField('lastHormoneTest', 'آخر فحص هرمونات', QuestionKind.text),
        QuestionField(
            'lastVitaminTest', 'آخر فحص فيتامينات', QuestionKind.text),
        QuestionField(
            'lastRenalLiverTest', 'آخر فحص كلى وكبد', QuestionKind.text),
        QuestionField('lastLipidTest', 'آخر فحص دهون', QuestionKind.text),
        QuestionField('lastSugarTest', 'آخر فحص سكر', QuestionKind.text),
      ],
    ),
    QuestionSection(
      title: 'ملاحظات ومشاركة وطوارئ',
      spokenOutline:
          'القسم الأخير: ملاحظات، صلاحية المشاركة، وإشارات تستدعي طوارئ وليست تشخيصاً.',
      fields: [
        QuestionField('currentHeadache', 'صداع حالياً', QuestionKind.yesNo),
        QuestionField('currentDizziness', 'دوخة حالياً', QuestionKind.yesNo),
        QuestionField('currentFatigue', 'تعب عام حالياً', QuestionKind.yesNo),
        QuestionField('currentFever', 'حمى حالياً', QuestionKind.yesNo),
        QuestionField('emergencyChestPain', 'ألم صدر حاد', QuestionKind.yesNo),
        QuestionField(
            'emergencyLossOfConsciousness', 'فقدان وعي', QuestionKind.yesNo),
        QuestionField(
            'emergencySuddenParalysis', 'شلل مفاجئ', QuestionKind.yesNo),
        QuestionField(
            'emergencySevereBreathing', 'صعوبة تنفس شديدة', QuestionKind.yesNo),
        QuestionField('emergencyBleeding', 'نزيف', QuestionKind.yesNo),
        QuestionField(
            'emergencyNotes', 'تعليمات طوارئ خاصة', QuestionKind.text),
        QuestionField('generalNotes', 'ملاحظات إضافية', QuestionKind.text),
        QuestionField('shareWithDoctor',
            'السماح للطبيب المعتمد برؤية هذه البيانات', QuestionKind.yesNo),
        QuestionField('shareWithEmergency', 'السماح للطوارئ برؤية الضروري منها',
            QuestionKind.yesNo),
      ],
    ),
    QuestionSection(
      title: 'صور تخدم الاستبيان إن شئت',
      spokenOutline:
          'قسم اختياري: قرحة فراش، لسان، جلد، شعر، شرايين بارزة. الكاميرا الذكية إشارة تقريبية من المرجع المحلي وليست تشخيصاً.',
      fields: [
        QuestionField('photoBedsore', 'صورة قرحة الفراش أو السرير إن وُجدت',
            QuestionKind.photo),
        QuestionField('photoTongue', 'صورة اللسان', QuestionKind.photo),
        QuestionField('photoSkin', 'صورة الجلد', QuestionKind.photo),
        QuestionField('photoHair', 'صورة الشعر', QuestionKind.photo),
        QuestionField('photoVessel', 'صورة الشرايين البارزة إن وُجدت',
            QuestionKind.photo),
        QuestionField(
            'photoNotes', 'وصف ما تراه في الصور بكلماتك', QuestionKind.text),
      ],
    ),
  ];

  static List<String> allKeys() => [
        for (final section in sections)
          for (final field in section.fields) field.key,
      ];
}
