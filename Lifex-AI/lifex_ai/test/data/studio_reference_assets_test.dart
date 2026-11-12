import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/local_knowledge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('مراجع Android Studio تُحمَّل كـ JSON صالح', () async {
    final camera =
        jsonDecode(await rootBundle.loadString('lib/data/reference/SmartCameraSigns.json'));
    final growth =
        jsonDecode(await rootBundle.loadString('lib/data/reference/Height_Weight.json'));
    final drugs =
        jsonDecode(await rootBundle.loadString('lib/data/reference/drugs/Antibiotics.json'));
    final skin =
        jsonDecode(await rootBundle.loadString('lib/data/reference/skin_hair_conditions.json'));
    final face =
        jsonDecode(await rootBundle.loadString('lib/data/reference/face_sign_extras.json'));

    expect(camera, isA<List>());
    expect((camera as List).length, greaterThan(50));
    expect(growth, isA<List>());
    expect(drugs, isA<List>());
    expect((drugs as List).first['name'], isNotNull);
    expect((skin as List).length, greaterThan(200));
    expect((face as List).length, greaterThan(10));
    final incoming = jsonDecode(
      await rootBundle.loadString('lib/data/reference/incoming_reference.json'),
    );
    expect(incoming, isA<List>());
    expect((incoming as List).length, greaterThan(100));
    expect(incoming.first['source'], isNotNull);
  });

  test('تطابق الأعراض مرجع توعية وليس تشخيصاً', () {
    final knowledge = LocalKnowledge(
      diseases: const [],
      medications: const [],
      symptoms: const [],
      tests: const [],
      namedConditions: const [
        {
          'name': 'الثآليل الأخمصية (Plantar Warts)',
          'description': 'ثآليل القدم',
          'symptoms': ['ألم عند المشي', 'نقاط سوداء'],
        },
      ],
      cameraSigns: const [
        {'sign': 'Thinning Eyebrows', 'meaning': 'قد يُذكر مع قصور الدرق'},
      ],
      disclaimerAr: 'مرجع توعية فقط. ليس تشخيصاً.',
    );
    final hits = knowledge.rankByEnteredClues(symptoms: ['ألم عند المشي']);
    expect(hits, isNotEmpty);
    expect(hits.first.titleAr, contains('الثآليل'));
    expect(hits.first.detailAr, contains('ليس تشخيصاً'));
    expect(knowledge.rankByEnteredClues(symptoms: const []), isEmpty);
  });
}
