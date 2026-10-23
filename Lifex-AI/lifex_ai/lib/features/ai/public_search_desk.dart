/// =============================================================
/// Lifex-AI — بحث عام بلا مفتاح
/// خلاصة من محرك عام. المفتاح يبقى اختياراً للمحرك المربوط.
/// الخلاصة الفارغة تبقى فارغة.
/// =============================================================
library lifex_ai.features.ai.public_search_desk;

import 'dart:convert';

import 'package:http/http.dart' as http;

class PublicSearchAnswer {
  const PublicSearchAnswer({
    required this.textAr,
    required this.received,
  });

  final String textAr;
  final bool received;
}

class PublicSearchDesk {
  const PublicSearchDesk({http.Client? client}) : _client = client;

  final http.Client? _client;

  static Uri endpoint(String query) {
    return Uri.https('api.duckduckgo.com', '/', {
      'q': query.trim(),
      'format': 'json',
      'no_html': '1',
      'skip_disambig': '1',
    });
  }

  Future<PublicSearchAnswer> ask(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      return const PublicSearchAnswer(textAr: '', received: false);
    }
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client.get(
        endpoint(text),
        headers: const {'User-Agent': 'Lifex-AI'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return const PublicSearchAnswer(
          textAr: 'محرك البحث العام رد برمز غير ناجح. لم يُخترع نص.',
          received: false,
        );
      }
      return readBody(response.body);
    } catch (_) {
      return const PublicSearchAnswer(
        textAr:
            'محرك البحث العام لم يُفتح من هذا الجهاز. المرجع المحلي يبقى، والمفتاح اختياري.',
        received: false,
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  static PublicSearchAnswer readBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const PublicSearchAnswer(
          textAr: 'رد المحرك العام ليس خلاصة. لم يُخترع نص.',
          received: false,
        );
      }
      final abstract = '${decoded['AbstractText'] ?? ''}'.trim();
      final heading = '${decoded['Heading'] ?? ''}'.trim();
      if (abstract.isNotEmpty) {
        final title = heading.isEmpty ? '' : '$heading. ';
        return PublicSearchAnswer(textAr: '$title$abstract', received: true);
      }
      final related = decoded['RelatedTopics'];
      if (related is List) {
        for (final item in related) {
          if (item is! Map) continue;
          final line = '${item['Text'] ?? ''}'.trim();
          if (line.isNotEmpty) {
            return PublicSearchAnswer(textAr: line, received: true);
          }
        }
      }
      return const PublicSearchAnswer(
        textAr: 'المحرك العام لم يعرض خلاصة لهذه العبارة.',
        received: true,
      );
    } catch (_) {
      return const PublicSearchAnswer(
        textAr: 'تعذّر قراءة رد المحرك العام. لم يُخترع نص.',
        received: false,
      );
    }
  }
}
