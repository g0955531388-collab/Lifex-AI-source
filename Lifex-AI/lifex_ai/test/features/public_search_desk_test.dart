import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/ai/public_search_desk.dart';

void main() {
  test('الخلاصة تُقرأ والمفتاح لا يدخل في الرابط', () {
    final uri = PublicSearchDesk.endpoint('كرسي');
    expect(uri.host, 'api.duckduckgo.com');
    expect(uri.queryParameters.containsKey('key'), isFalse);
    expect(uri.queryParameters['q'], 'كرسي');
    final answer = PublicSearchDesk.readBody(
      '{"Heading":"Chair","AbstractText":"A seat.","RelatedTopics":[]}',
    );
    expect(answer.received, isTrue);
    expect(answer.textAr, 'Chair. A seat.');
  });

  test('بلا خلاصة يؤخذ أول موضوع مرتبط', () {
    final answer = PublicSearchDesk.readBody(
      '{"AbstractText":"","RelatedTopics":[{"Text":"باب للغرفة"}]}',
    );
    expect(answer.received, isTrue);
    expect(answer.textAr, 'باب للغرفة');
  });

  test('الجسم التالف لا يُخترع له نص', () {
    final answer = PublicSearchDesk.readBody('ليس جسون');
    expect(answer.received, isFalse);
    expect(answer.textAr, contains('لم يُخترع'));
  });
}
