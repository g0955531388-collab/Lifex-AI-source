/// بحث خارجي عبر صفحات المحركات الرسمية. النتائج تبقى في المتصفح.
library lifex_ai.features.search.external_search_catalog;

import 'dart:convert';

class WebEngine {
  const WebEngine({
    required this.id,
    required this.labelAr,
    required this.host,
    required this.build,
  });

  final String id;
  final String labelAr;
  final String host;
  final Uri Function(String query) build;
}

class ExternalSearchCatalog {
  ExternalSearchCatalog._();

  static const preferenceKey = 'lifex_web_engine';
  static const defaultId = 'duckduckgo';

  static const offerAr =
      'لم أعثر على نتيجة داخل Lifex-AI. هل تريد توسيع البحث عبر الإنترنت؟';

  static final List<WebEngine> engines = [
    WebEngine(
      id: 'duckduckgo',
      labelAr: 'DuckDuckGo',
      host: 'duckduckgo.com',
      build: (query) => Uri.https('duckduckgo.com', '/', {'q': query}),
    ),
    WebEngine(
      id: 'google',
      labelAr: 'Google',
      host: 'www.google.com',
      build: (query) => Uri.https('www.google.com', '/search', {'q': query}),
    ),
    WebEngine(
      id: 'bing',
      labelAr: 'Bing',
      host: 'www.bing.com',
      build: (query) => Uri.https('www.bing.com', '/search', {'q': query}),
    ),
    WebEngine(
      id: 'brave',
      labelAr: 'Brave Search',
      host: 'search.brave.com',
      build: (query) => Uri.https('search.brave.com', '/search', {'q': query}),
    ),
  ];

  static WebEngine byId(String? id) {
    for (final engine in engines) {
      if (engine.id == id) return engine;
    }
    return engines.first;
  }

  static Uri? queryOf(String? engineId, String text) {
    final query = text.trim();
    if (query.isEmpty) return null;
    return byId(engineId).build(query);
  }

  /// يُسقط فعل البحث ويبقي العبارة التي تُرسل، وهي نص المستخدم فقط.
  static String phraseOf(String raw) {
    var text = raw.trim();
    const prefixes = [
      'ابحث في الإنترنت عن',
      'ابحث في الإنترنت',
      'بحث الإنترنت عن',
      'ابحث عن',
      'ابحث',
      'search the web for',
      'search the web',
      'search online for',
      'search for',
      'search',
    ];
    final folded = text.toLowerCase();
    for (final prefix in prefixes) {
      if (text.startsWith(prefix) || folded.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
        break;
      }
    }
    return text;
  }
}

class UserEngineDraft {
  const UserEngineDraft._();

  static const preferenceKey = 'lifex_user_web_engines';

  /// يرفض الرابط الناقص. فتح موقع ذكاء ليس دمجاً لواجهة برمجية.
  static String? rejection(String label, String template) {
    if (label.trim().isEmpty) return 'اكتب اسماً للمحرك.';
    final raw = template.trim();
    if (!raw.contains('{query}')) {
      return 'الرابط يجب أن يحتوي {query} مكان نص البحث.';
    }
    final probe = raw.replaceAll('{query}', 'lifex');
    final uri = Uri.tryParse(probe);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'يُقبل رابط https مكتمل فقط. الرابط الناقص لا يُفتح.';
    }
    return null;
  }

  static WebEngine? toEngine({
    required String id,
    required String label,
    required String template,
  }) {
    if (rejection(label, template) != null) return null;
    final host = Uri.parse(template.trim().replaceAll('{query}', 'lifex')).host;
    return WebEngine(
      id: id,
      labelAr: label.trim(),
      host: host,
      build: (query) => Uri.parse(
        template.trim().replaceAll('{query}', Uri.encodeQueryComponent(query)),
      ),
    );
  }

  static String encode(List<WebEngine> engines, Map<String, String> templates) {
    return jsonEncode([
      for (final engine in engines)
        if (templates[engine.id] != null)
          {
            'id': engine.id,
            'label': engine.labelAr,
            'template': templates[engine.id],
          },
    ]);
  }

  static List<({WebEngine engine, String template})> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <({WebEngine engine, String template})>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final id = '${item['id'] ?? ''}'.trim();
        final label = '${item['label'] ?? ''}'.trim();
        final template = '${item['template'] ?? ''}'.trim();
        final engine = toEngine(id: id, label: label, template: template);
        if (engine == null || id.isEmpty) continue;
        out.add((engine: engine, template: template));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class SearchHandoff {
  const SearchHandoff._();

  static bool offerInternet({
    required String query,
    required int localHits,
    required bool lookupFailed,
    bool sourcesReady = true,
  }) {
    if (!sourcesReady || lookupFailed || query.trim().isEmpty) return false;
    return localHits <= 0;
  }

  static const emptyAr =
      'لا نتائج داخل مصادر Lifex-AI المتاحة لهذا النص. هذا ليس حكماً بأن المعلومة غير موجودة خارج التطبيق.';

  static const failedAr =
      'تعذّر البحث الداخلي. هذا فشل في التنفيذ وليس نتيجة فارغة.';

  static const unloadedAr =
      'بيانات البحث الداخلي لم تُحمّل بعد. هذا ليس نتيجة فارغة.';
}
