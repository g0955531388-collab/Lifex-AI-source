/// دليل روابط رسمية. الرابط صفحة الناشر، وليس ملفاً يُثبَّت تلقائياً.
library lifex_ai.features.knowledge.official_resource;

enum ResourceKind {
  cameraPlatform,
  visionModel,
  ocr,
  barcode,
  bookCatalog,
  bookDownload,
  bibliography,
}

class OfficialResource {
  const OfficialResource({
    required this.name,
    required this.kind,
    required this.publisher,
    required this.platformAr,
    required this.requirementAr,
    required this.licenseAr,
    required this.checkedOn,
    required this.page,
    required this.noteAr,
  });

  final String name;
  final ResourceKind kind;
  final String publisher;
  final String platformAr;
  final String requirementAr;
  final String licenseAr;
  final String checkedOn;
  final Uri page;
  final String noteAr;

  String get kindAr {
    switch (kind) {
      case ResourceKind.cameraPlatform:
        return 'منصة كاميرا';
      case ResourceKind.visionModel:
        return 'مدخل نماذج';
      case ResourceKind.ocr:
        return 'تعرف على النص';
      case ResourceKind.barcode:
        return 'باركود';
      case ResourceKind.bookCatalog:
        return 'فهرس كتب';
      case ResourceKind.bookDownload:
        return 'نسخ يقررها المصدر';
      case ResourceKind.bibliography:
        return 'بيانات ببليوغرافية';
    }
  }
}

class OfficialResourceCatalog {
  OfficialResourceCatalog._();

  static const checkedOn = '2026-10-14';

  static final List<OfficialResource> vision = [
    OfficialResource(
      name: 'Google ML Kit',
      kind: ResourceKind.ocr,
      publisher: 'Google',
      platformAr: 'Android عبر المكوّنات المضافة في التطبيق',
      requirementAr: 'حزم ML Kit المبنية حالياً: نص لاتيني، باركود، تسميات صور.',
      licenseAr: 'شروط Google ML Kit',
      checkedOn: checkedOn,
      page: Uri.parse('https://developers.google.com/ml-kit'),
      noteAr: 'مدخل وثائق. ليس تعريف كاميرا ولا نموذجاً يُنزَّل تلقائياً.',
    ),
    OfficialResource(
      name: 'TensorFlow Lite',
      kind: ResourceKind.visionModel,
      publisher: 'Google',
      platformAr: 'Android عند إضافة مفسّر ونموذج محددين',
      requirementAr: 'نموذج متوافق وترخيص واضح قبل أي تشغيل.',
      licenseAr: 'يُحدد مع كل نموذج',
      checkedOn: checkedOn,
      page: Uri.parse('https://www.tensorflow.org/lite'),
      noteAr: 'منصة تشغيل نماذج. لا يوجد نموذج مثبّت من هذه الصفحة وحدها.',
    ),
    OfficialResource(
      name: 'Hugging Face Models',
      kind: ResourceKind.visionModel,
      publisher: 'Hugging Face',
      platformAr: 'الويب؛ التشغيل على الجهاز يحتاج نموذجاً ومحركاً منفصلين',
      requirementAr: 'مراجعة ترخيص النموذج وحجمه قبل اختياره.',
      licenseAr: 'يختلف حسب النموذج',
      checkedOn: checkedOn,
      page: Uri.parse('https://huggingface.co/models'),
      noteAr: 'فهرس نماذج. Lifex-AI لا يثبّت ملفاً من هذا الفهرس تلقائياً.',
    ),
    OfficialResource(
      name: 'Android CameraX',
      kind: ResourceKind.cameraPlatform,
      publisher: 'Android',
      platformAr: 'Android',
      requirementAr: 'تطبيق الكاميرا الحالي يستخدم حزمة camera في Flutter.',
      licenseAr: 'وثائق Android',
      checkedOn: checkedOn,
      page: Uri.parse('https://developer.android.com/media/camera/camerax'),
      noteAr: 'مرجع منصة التصوير. منفصل عن نموذج تفسير الصورة.',
    ),
    OfficialResource(
      name: 'MediaPipe',
      kind: ResourceKind.visionModel,
      publisher: 'Google',
      platformAr: 'Android عند اختيار حل موثّق لكل مهمة',
      requirementAr: 'كل حل يُراجع على حدة. ليس كل حل مناسباً للمكفوفين تلقائياً.',
      licenseAr: 'شروط MediaPipe',
      checkedOn: checkedOn,
      page: Uri.parse('https://developers.google.com/mediapipe'),
      noteAr: 'مدخل حلول رؤية. لا يُثبَّت نموذج من هذه الصفحة وحدها.',
    ),
    OfficialResource(
      name: 'LiteRT',
      kind: ResourceKind.visionModel,
      publisher: 'Google',
      platformAr: 'إطار تشغيل نماذج متوافقة، وليس نموذج تعرّف',
      requirementAr: 'نموذج بصيغة متوافقة واختبار على Android قبل الاعتماد.',
      licenseAr: 'شروط LiteRT، وترخيص كل نموذج على حدة',
      checkedOn: checkedOn,
      page: Uri.parse('https://ai.google.dev/edge/litert'),
      noteAr: 'صفحة الإطار. لا تعني أن تسمية المشهد الحالية تعمل عبر LiteRT.',
    ),
    OfficialResource(
      name: 'MediaPipe.dev',
      kind: ResourceKind.visionModel,
      publisher: 'Google',
      platformAr: 'مرجع الحلول، ويُراجع كل حل على حدة',
      requirementAr: 'لا يُعد فتح الصفحة دمجاً داخل التطبيق.',
      licenseAr: 'شروط MediaPipe',
      checkedOn: checkedOn,
      page: Uri.parse('https://mediapipe.dev/'),
      noteAr: 'رابط مرجعي للتحقق. لم يُفحص HTTP في هذا البناء.',
    ),
  ];

  static final List<OfficialResource> books = [
    OfficialResource(
      name: 'Open Library',
      kind: ResourceKind.bookCatalog,
      publisher: 'Internet Archive',
      platformAr: 'ويب',
      requirementAr: 'القراءة أو الاستعارة حسب صفحة الكتاب على الموقع.',
      licenseAr: 'شروط Open Library',
      checkedOn: checkedOn,
      page: Uri.parse('https://openlibrary.org/'),
      noteAr: 'فهرس وقراءة حين يتيحها المصدر. ليس كل كتاب مجانياً.',
    ),
    OfficialResource(
      name: 'Internet Archive',
      kind: ResourceKind.bookDownload,
      publisher: 'Internet Archive',
      platformAr: 'ويب',
      requirementAr: 'التنزيل يظهر فقط إذا أتاحه المصدر للعمل نفسه.',
      licenseAr: 'شروط Internet Archive',
      checkedOn: checkedOn,
      page: Uri.parse('https://archive.org/'),
      noteAr: 'مواد مختلطة. التوفر يقرره الموقع لا التطبيق.',
    ),
    OfficialResource(
      name: 'Project Gutenberg',
      kind: ResourceKind.bookDownload,
      publisher: 'Project Gutenberg',
      platformAr: 'ويب',
      requirementAr: 'الكتب الظاهرة في المجال العام وفق شروطهم.',
      licenseAr: 'شروط Project Gutenberg',
      checkedOn: checkedOn,
      page: Uri.parse('https://www.gutenberg.org/'),
      noteAr: 'مدخل لنسخ يتيحها غوتنبرغ. ليس ضماناً لكل عنوان.',
    ),
    OfficialResource(
      name: 'Google Books',
      kind: ResourceKind.bibliography,
      publisher: 'Google',
      platformAr: 'ويب',
      requirementAr: 'المعاينة أو الشراء حسب الناشر.',
      licenseAr: 'شروط Google Books',
      checkedOn: checkedOn,
      page: Uri.parse('https://books.google.com/'),
      noteAr: 'بيانات الكتاب ومعاينة محدودة غالباً. ليست تنزيلاً مجانياً عاماً.',
    ),
    OfficialResource(
      name: 'WorldCat',
      kind: ResourceKind.bibliography,
      publisher: 'OCLC',
      platformAr: 'ويب',
      requirementAr: 'الفهرس يدل على مكتبات تحمل التسجيلة.',
      licenseAr: 'شروط WorldCat',
      checkedOn: checkedOn,
      page: Uri.parse('https://www.worldcat.org/'),
      noteAr: 'فهرس مكتبات. لا ينزّل نص الكتاب إلى Lifex-AI.',
    ),
  ];

  static Uri bookQuery(OfficialResource resource, String phrase) {
    final query = phrase.trim();
    if (query.isEmpty) return resource.page;
    switch (resource.name) {
      case 'Open Library':
        return Uri.https('openlibrary.org', '/search', {'q': query});
      case 'Internet Archive':
        return Uri.https('archive.org', '/search', {'query': query});
      case 'Project Gutenberg':
        return Uri.https(
          'www.gutenberg.org',
          '/ebooks/search/',
          {'query': query},
        );
      case 'Google Books':
        return Uri.https('books.google.com', '/books', {'q': query});
      case 'WorldCat':
        return Uri.https('www.worldcat.org', '/search', {'q': query});
      default:
        return resource.page;
    }
  }
}
