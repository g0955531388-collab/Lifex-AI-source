import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lasting_search_index.dart';
import 'package:lifex_ai/core/local_knowledge.dart';
import 'package:lifex_ai/core/medical_record_canon.dart';
import 'package:lifex_ai/features/search/search_readout.dart';

LocalKnowledge knowledge() => LocalKnowledge(
      diseases: const [
        {'nameAr': 'السكري من النوع الثاني', 'nameEn': 'Type 2 diabetes'},
        {'nameAr': 'ارتفاع ضغط الدم', 'nameEn': 'Hypertension'},
      ],
      medications: const [
        {'nameAr': 'باراسيتامول', 'nameEn': 'Paracetamol'},
      ],
      symptoms: const [],
      tests: const [],
      namedConditions: const [],
      cameraSigns: const [],
      disclaimerAr: 'مرجع توعية فقط.',
    );

void main() {
  group('المطابقة التقريبية', () {
    test('حرف خاطئ في الكلمة يُقبل', () {
      expect(MedicalRecordCanon.queryMatchesNear('Type 2 diabetes', 'diabetis'),
          isTrue);
      expect(MedicalRecordCanon.queryMatchesNear('باراسيتامول', 'باراستامول'),
          isTrue);
      expect(MedicalRecordCanon.queryMatchesNear('ارتفاع ضغط الدم', 'ضغت'),
          isFalse,
          reason: 'كلمة من ثلاثة أحرف تتطلب تطابقاً تاماً');
    });

    test('أداة التعريف لا تمنع التطابق', () {
      expect(MedicalRecordCanon.queryMatchesNear('السكري', 'سكرى'), isTrue);
    });

    test('كلمة بعيدة لا تُطابق', () {
      expect(MedicalRecordCanon.queryMatchesNear('Hypertension', 'migraine'),
          isFalse);
    });

    test('المطابقة الحرفية لم تتغير', () {
      expect(MedicalRecordCanon.queryMatches('Type 2 diabetes', 'diabetis'),
          isFalse);
      expect(MedicalRecordCanon.queryMatches('Type 2 diabetes', 'diabetes'),
          isTrue);
    });
  });

  group('البحث الداخلي', () {
    test('التقريبي يجد ما لم يجده الحرفي', () {
      final engine = InternalSearchEngine(
        knowledge: knowledge(),
        lasting: LastingSearchIndex(),
      );
      expect(engine.search('diabetis'), isEmpty);
      final near = engine.searchNear('diabetis');
      expect(near.map((hit) => hit.titleAr), contains('السكري من النوع الثاني'));
    });

    test('الحرفي يبقى كما كان', () {
      final engine = InternalSearchEngine(
        knowledge: knowledge(),
        lasting: LastingSearchIndex(),
      );
      expect(engine.search('باراسيتامول').single.kindAr, 'دواء');
    });
  });

  group('بطاقة النطق', () {
    const hits = [
      KnowledgeHit(kindAr: 'مرض', titleAr: 'السكري', detailAr: ''),
      KnowledgeHit(kindAr: 'دواء', titleAr: 'ميتفورمين', detailAr: ''),
    ];

    test('كل نتيجة بمصدرها والخاتمة تنبيه المرجع', () {
      final text = SearchReadout.compose(
        query: 'سكري',
        hits: hits,
        approximate: false,
        english: false,
      );
      expect(text, contains('وجدت 2 نتيجة'));
      expect(text, contains('السكري. المصدر: مرجع محلي، مرض.'));
      expect(text, endsWith('مرجع توعية فقط. ليس تشخيصاً ولا بديلاً عن الطبيب.'));
    });

    test('التقريبي يُعلن أنه تقريبي', () {
      final text = SearchReadout.compose(
        query: 'سكرى',
        hits: hits,
        approximate: true,
        english: false,
      );
      expect(text, contains('لا تطابق حرفي'));
      expect(text, contains('تحقّق من الاسم'));
    });

    test('الخلاصة العامة موسومة، والإنجليزية بمصدرها', () {
      final text = SearchReadout.compose(
        query: 'diabetes',
        hits: hits,
        approximate: false,
        english: true,
        publicSummary: 'A chronic condition.',
      );
      expect(text, contains('Source: local reference'));
      expect(text, contains('Public engine summary without a key: A chronic condition.'));
      expect(text, contains('Not a diagnosis'));
    });

    test('بلا نتائج لا يخترع شيئاً', () {
      final text = SearchReadout.compose(
        query: 'xyz',
        hits: const [],
        approximate: false,
        english: false,
      );
      expect(text, startsWith('لا نتيجة داخل Lifex-AI'));
    });

    test('ثلاث نتائج كحد أقصى في النطق', () {
      final many = [
        for (var i = 0; i < 6; i++)
          KnowledgeHit(kindAr: 'مرض', titleAr: 'حالة $i', detailAr: ''),
      ];
      final text = SearchReadout.compose(
        query: 'حالة',
        hits: many,
        approximate: false,
        english: false,
      );
      expect(text, contains('3. حالة 2'));
      expect(text, isNot(contains('حالة 3')));
    });
  });
}
