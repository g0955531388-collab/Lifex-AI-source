import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/screen_voice_board.dart';
import 'package:lifex_ai/features/knowledge/official_resource.dart';
import 'package:lifex_ai/features/search/external_link_desk.dart';
import 'package:lifex_ai/features/search/external_search_catalog.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  test('البحث الداخلي الفارغ يقترح الإنترنت والفشل لا يُعامل كفراغ', () {
    expect(
      SearchHandoff.offerInternet(
        query: 'دواء نادر',
        localHits: 0,
        lookupFailed: false,
      ),
      isTrue,
    );
    expect(
      SearchHandoff.offerInternet(
        query: 'دواء نادر',
        localHits: 0,
        lookupFailed: false,
        sourcesReady: false,
      ),
      isFalse,
    );
    expect(
      ExternalSearchCatalog.offerAr,
      'لم أعثر على نتيجة داخل Lifex-AI. هل تريد توسيع البحث عبر الإنترنت؟',
    );
    expect(SearchHandoff.unloadedAr, contains('لم تُحمّل'));
    expect(SearchHandoff.failedAr, isNot(contains('لا نتائج')));
    expect(
      SearchHandoff.offerInternet(
        query: 'دواء',
        localHits: 2,
        lookupFailed: false,
      ),
      isFalse,
    );
    expect(
      SearchHandoff.offerInternet(
        query: 'دواء',
        localHits: 0,
        lookupFailed: true,
      ),
      isFalse,
    );
    expect(SearchHandoff.emptyAr, isNot(contains('غير موجودة عالمياً')));
  });

  test('رابط المحرك المختار يُبنى ولا يُعرض كنتيجة داخل التطبيق', () {
    final uri = ExternalSearchCatalog.queryOf('google', 'باراسيتامول');
    expect(uri, isNotNull);
    expect(uri!.host, 'www.google.com');
    expect(uri.queryParameters['q'], 'باراسيتامول');
    expect(uri.queryParameters.keys, ['q']);
    expect(ExternalSearchCatalog.queryOf('bing', '  '), isNull);
    expect(
      ExternalSearchCatalog.phraseOf('ابحث في الإنترنت عن ضغط الدم'),
      'ضغط الدم',
    );
  });

  test('فتح الرابط يعتمد على النتيجة الفعلية للفتح', () async {
    final desk = ExternalLinkDesk(opener: (uri) async => uri.host == 'ok.test');
    final opened = await desk.open(Uri.parse('https://ok.test/a'));
    final closed = await desk.open(Uri.parse('https://no.test/a'));
    expect(opened.opened, isTrue);
    expect(opened.messageAr, contains('ليس نتيجة داخل'));
    expect(closed.opened, isFalse);
  });

  test('أوامر المكتبة والرجوع والبحث الخارجي تُفهم', () {
    final parser = CommandParser();
    expect(parser.parse('افتح المكتبة').intent, VoiceCommandIntent.openLibrary);
    expect(parser.parse('ارجع').intent, VoiceCommandIntent.goBack);
    expect(
      parser.parse('ابحث في الإنترنت عن دواء').intent,
      VoiceCommandIntent.openWebSearch,
    );
    expect(parser.parse('ابحث عن دواء').intent, VoiceCommandIntent.openSearch);
    expect(parser.parse('أوقف القراءة').intent, VoiceCommandIntent.stopReading);
    expect(parser.parse('صف المشهد').intent, VoiceCommandIntent.openLiveSight);
    expect(parser.parse('اقرأ ما أمامي').intent, VoiceCommandIntent.openLiveSight);
    expect(parser.parse('ماذا يوجد أمامي؟').intent, VoiceCommandIntent.openLiveSight);
    expect(parser.parse('أسرع القراءة').intent, VoiceCommandIntent.fasterReading);
    expect(parser.parse('أبطئ القراءة').intent, VoiceCommandIntent.slowReading);
    expect(parser.parse('اقرأ الباركود').intent, VoiceCommandIntent.readBarcode);
    expect(
      parser.parse('حدّث ذكاء الكاميرا الآن').intent,
      VoiceCommandIntent.updateCameraMind,
    );
    expect(
      parser.parse('أوقف التحديث التلقائي').intent,
      VoiceCommandIntent.disableAutoModelUpdate,
    );
    expect(
      parser.parse('وسّع البحث عبر الإنترنت').intent,
      VoiceCommandIntent.openWebSearch,
    );
    expect(parser.parse('ابحث عن كتاب').intent, VoiceCommandIntent.openLibrary);
    expect(parser.parse('اقرأ النتائج').intent, VoiceCommandIntent.readScreen);
    expect(
      parser.parse('ارجع إلى الشاشة الرئيسية').intent,
      VoiceCommandIntent.goHome,
    );
    expect(parser.parse('توقف عن الكلام').intent, VoiceCommandIntent.stopReading);
    expect(parser.parse('افتح البحث الداخلي').intent, VoiceCommandIntent.openSearch);
    expect(
      parser.parse('موارد الكاميرا').intent,
      VoiceCommandIntent.openVisionResources,
    );
  });

  test('قراءة الشاشة تتبع الشاشة الظاهرة فقط', () {
    final board = ScreenVoiceBoard.instance..clearForTest();
    final home = Object();
    final library = Object();
    board.upsert(ScreenVoiceCard(token: home, titleAr: 'الرئيسية'));
    board.upsert(
      ScreenVoiceCard(
        token: library,
        titleAr: 'مكتبة Lifex-AI',
        controlsAr: const ['فتح فهرس الناشر'],
      ),
    );
    expect(board.readingAr(), contains('مكتبة'));
    board.remove(library);
    expect(board.readingAr(), contains('الرئيسية'));
    expect(CommandParser().parse('اقرأ الشاشة').intent, VoiceCommandIntent.readScreen);
    board.clearForTest();
  });

  test('دليل الموارد يبقي روابط الناشر وتاريخ التحقق', () {
    final names = [
      ...OfficialResourceCatalog.vision.map((item) => item.page.host),
      ...OfficialResourceCatalog.books.map((item) => item.page.host),
    ];
    expect(names, contains('developers.google.com'));
    expect(names, contains('www.tensorflow.org'));
    expect(names, contains('huggingface.co'));
    expect(names, contains('developer.android.com'));
    expect(names, contains('ai.google.dev'));
    expect(names, contains('mediapipe.dev'));
    expect(names, contains('openlibrary.org'));
    expect(names, contains('archive.org'));
    expect(names, contains('www.gutenberg.org'));
    expect(names, contains('books.google.com'));
    expect(names, contains('www.worldcat.org'));
    expect(
      OfficialResourceCatalog.vision.every(
        (item) => item.checkedOn == '2026-10-14',
      ),
      isTrue,
    );
    final book = OfficialResourceCatalog.bookQuery(
      OfficialResourceCatalog.books.first,
      'طب',
    );
    expect(book.host, 'openlibrary.org');
    expect(book.queryParameters['q'], 'طب');
  });

  test('محرك المستخدم يُرفض إذا لم يكن https وفيه موضع البحث', () {
    expect(UserEngineDraft.rejection('مثال', 'http://example.com/?q={query}'), isNotNull);
    expect(UserEngineDraft.rejection('مثال', 'https://example.com/search'), isNotNull);
    final engine = UserEngineDraft.toEngine(
      id: 'custom',
      label: 'مثال',
      template: 'https://example.com/search?q={query}',
    );
    expect(engine, isNotNull);
    expect(engine!.build('كتاب').queryParameters['q'], 'كتاب');
    final saved = UserEngineDraft.encode(
      [engine],
      {'custom': 'https://example.com/search?q={query}'},
    );
    final back = UserEngineDraft.decode(saved);
    expect(back, hasLength(1));
    expect(back.first.engine.host, 'example.com');
  });
}
