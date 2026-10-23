/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: ai_service_router.dart
/// المسار: lib/features/ai/ai_service_router.dart
/// الوصف: يوجّه استعلام المستخدم للمحرك الخارجي المختار (عبر
/// UnifiedAiHubGateway)، وينفّذ الاتصال الفعلي بواجهة برمجة كل محرك،
/// مع إرفاق "تعريف التطبيق" (App Attribution) الحقيقي في كل طلب حتى
/// يتعرّف المحرك على أن الاستدعاء قادم من Lifex-AI Global Health
/// Network تحديداً.
///
/// ⚠️ لا يحتوي هذا الملف على أي ادّعاء بعدد مستخدمين أو إحصائيات غير
/// موثَّقة؛ "تعريف التطبيق" هنا يعني فقط إرسال اسم التطبيق ومعرّفه في
/// رأس الطلب (Header)، وهذا معيار قياسي تدعمه كل واجهات AI الكبرى.
/// =============================================================
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_constants.dart';
import '../../core/error_handler.dart';
import '../accessibility/gemini_bidi_session.dart';
import 'unified_ai_hub_gateway.dart';

/// معلومات تعريف التطبيق التي تُرسَل مع كل طلب لأي محرك خارجي، حتى
/// يظهر Lifex-AI بوضوح كمصدر الطلب في لوحات تحكم مزوّدي الذكاء
/// الاصطناعي (وليس كطلب مجهول المصدر).
class AppAttributionHeader {
  static Map<String, String> build() => {
        'X-App-Name': AppConstants.appName,
        'X-App-Package': AppConstants.packageName,
        'X-App-Version': AppConstants.appVersion,
        'User-Agent': '${AppConstants.appName}/${AppConstants.appVersion}',
      };
}

/// نتيجة موحّدة لاستدعاء أي محرك خارجي، بغض النظر عن اختلاف صيغة رد
/// كل مزوّد داخلياً.
class ExternalAiResponse {
  final bool success;
  final String? responseText;
  final String? errorMessageAr;

  const ExternalAiResponse.success(this.responseText)
      : success = true,
        errorMessageAr = null;

  const ExternalAiResponse.failure(this.errorMessageAr)
      : success = false,
        responseText = null;
}

/// عقد أي محرك خارجي فعلي — كل محرك (Gemini/ChatGPT/Claude/مخصص) ينفّذ
/// هذا العقد بمنطقه الخاص بصيغة الطلب/الرد المطابقة لواجهته الرسمية.
abstract class ExternalAiEngineClient {
  ExternalAiProvider get provider;

  Future<ExternalAiResponse> sendQuery({
    required String query,
    required String apiKeyOrToken,
    Map<String, String>? extraHeaders,
  });
}

/// يختار نموذجاً يولّد نصاً من قائمة Gemini. يفضّل flash ويتجاوز التضمين.
String? chooseGeminiModelName(List<dynamic> models) {
  String? fallback;
  for (final item in models) {
    if (item is! Map) continue;
    final name = item['name'];
    if (name is! String || name.isEmpty) continue;
    final methods = item['supportedGenerationMethods'];
    if (methods is List && !methods.contains('generateContent')) continue;
    final lower = name.toLowerCase();
    if (lower.contains('embed') ||
        lower.contains('aqa') ||
        lower.contains('tts') ||
        lower.contains('image')) {
      continue;
    }
    fallback ??= name;
    if (lower.contains('flash')) return name;
  }
  return fallback;
}

/// يختار نموذجاً اسمه يحتوي live. غيابه لا يُستبدل بنموذج نصي.
String? chooseGeminiLiveModelName(List<dynamic> models) {
  String? fallback;
  for (final item in models) {
    if (item is! Map) continue;
    final name = item['name'];
    if (name is! String || name.isEmpty) continue;
    final lower = name.toLowerCase();
    if (!lower.contains('live')) continue;
    if (lower.contains('embed') ||
        lower.contains('tts') ||
        lower.contains('image')) {
      continue;
    }
    final methods = item['supportedGenerationMethods'];
    if (methods is List &&
        methods.isNotEmpty &&
        !methods.contains('bidiGenerateContent') &&
        !methods.contains('generateContent')) {
      continue;
    }
    fallback ??= name;
    if (lower.contains('flash') || lower.contains('3.8')) return name;
  }
  return fallback;
}

String? chooseOpenAiModelId(List<dynamic> models) {
  final ids = <String>[
    for (final item in models)
      if (item is Map && item['id'] is String) item['id'] as String,
  ];
  for (final preferred in const [
    'gpt-4o-mini',
    'gpt-4o',
    'gpt-4.1-mini',
    'gpt-4.1',
  ]) {
    if (ids.contains(preferred)) return preferred;
  }
  for (final id in ids) {
    if (id.startsWith('gpt-')) return id;
  }
  return null;
}

String? chooseClaudeModelId(List<dynamic> models) {
  final ids = <String>[
    for (final item in models)
      if (item is Map && item['id'] is String) item['id'] as String,
  ];
  for (final id in ids) {
    if (id.contains('sonnet')) return id;
  }
  if (ids.isEmpty) return null;
  return ids.first;
}

String readProviderError(String body, int statusCode) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        return 'رمز $statusCode. ${error['message']}';
      }
      if (error is String && error.isNotEmpty) {
        return 'رمز $statusCode. $error';
      }
    }
  } catch (_) {}
  final clip = body.length > 180 ? body.substring(0, 180) : body;
  return 'رمز $statusCode. $clip';
}

/// تنفيذ عميل Gemini — المحرك الأساسي المفضَّل لهذا المشروع، وفق
/// طلب صريح من مالك المشروع بعدم الاعتماد الحصري على محرك واحد.
class GeminiEngineClient implements ExternalAiEngineClient {
  GeminiEngineClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, String> _modelByKey = {};

  @override
  ExternalAiProvider get provider => ExternalAiProvider.gemini;

  @override
  Future<ExternalAiResponse> sendQuery({
    required String query,
    required String apiKeyOrToken,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final model = await _modelFor(apiKeyOrToken);
      if (model == null) {
        return ExternalAiResponse.failure(
          _modelByKey['error:$apiKeyOrToken'] ??
              'المفتاح لم يُرجع نموذجاً يولّد نصاً من Gemini.',
        );
      }
      var response = await _post(
        model: model,
        apiKeyOrToken: apiKeyOrToken,
        query: query,
        withSystem: true,
        extraHeaders: extraHeaders,
      );
      if (response.statusCode == 400) {
        response = await _post(
          model: model,
          apiKeyOrToken: apiKeyOrToken,
          query: query,
          withSystem: false,
          extraHeaders: extraHeaders,
        );
      }
      if (response.statusCode != 200) {
        return ExternalAiResponse.failure(
          'تعذّر جلب الرد من Gemini. ${readProviderError(response.body, response.statusCode)}',
        );
      }
      final decoded = jsonDecode(response.body);
      final text = decoded is Map<String, dynamic> ? _geminiText(decoded) : null;
      if (text == null) {
        return const ExternalAiResponse.failure(
          'رد Gemini وصل بلا نص قابل للعرض. الربط ما زال محفوظاً.',
        );
      }
      return ExternalAiResponse.success(text);
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'GEMINI_QUERY_FAILED',
        'فشل الاتصال بمحرك Gemini.',
        sourceModule: 'ai_service_router',
        exception: e,
        stackTrace: stackTrace,
      );
      return const ExternalAiResponse.failure(
        'حدث خطأ أثناء التواصل مع محرك Gemini. الربط ما زال محفوظاً.',
      );
    }
  }

  Future<String?> _modelFor(String apiKeyOrToken) async {
    final cached = _modelByKey[apiKeyOrToken];
    if (cached != null) return cached;
    final response = await _httpClient.get(
      Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models',
        {'key': apiKeyOrToken},
      ),
    );
    if (response.statusCode != 200) {
      _modelByKey['error:$apiKeyOrToken'] =
          'تعذّر قراءة نماذج Gemini. ${readProviderError(response.body, response.statusCode)}';
      return null;
    }
    final decoded = jsonDecode(response.body);
    final models = decoded is Map ? decoded['models'] : null;
    final chosen = chooseGeminiModelName(
      models is List ? models : const [],
    );
    if (chosen == null) {
      _modelByKey['error:$apiKeyOrToken'] =
          'قائمة Gemini بلا نموذج توليد نص. الربط ما زال محفوظاً.';
      return null;
    }
    _modelByKey[apiKeyOrToken] = chosen;
    return chosen;
  }

  /// اسم نموذج Live، أو النموذج الموثق إن أعادت القائمة 200 بلا اسم live.
  /// فشل المصادقة يعيد null ولا يُسجَّل المفتاح.
  Future<String?> liveModelName(String apiKeyOrToken) async {
    try {
      final response = await _httpClient
          .get(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models',
              {'key': apiKeyOrToken},
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final models = decoded is Map ? decoded['models'] : null;
      return chooseGeminiLiveModelName(models is List ? models : const []) ??
          geminiLiveModelFallback;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _post({
    required String model,
    required String apiKeyOrToken,
    required String query,
    required bool withSystem,
    Map<String, String>? extraHeaders,
  }) {
    final resource = model.startsWith('models/') ? model : 'models/$model';
    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': query}
          ]
        }
      ],
    };
    if (withSystem) {
      body['system_instruction'] = {
        'parts': [
          {'text': lifexAiSystemContext}
        ]
      };
    }
    return _httpClient.post(
      Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/$resource:generateContent',
        {'key': apiKeyOrToken},
      ),
      headers: {
        'Content-Type': 'application/json',
        ...AppAttributionHeader.build(),
        ...?extraHeaders,
      },
      body: jsonEncode(body),
    );
  }

  String? _geminiText(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;
    final part = parts.first;
    if (part is! Map) return null;
    final text = part['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return text;
  }
}

/// تعليمة نظامية (System Instruction) موحّدة تُرسَل مع كل استدعاء لأي
/// محرك خارجي يدعم هذا المفهوم، لتعريفه بسياق أنه يعمل بالنيابة عن
/// تطبيق Lifex-AI تحديداً — دون أي ادّعاء إحصائي غير موثَّق.
const String lifexAiSystemContext =
    'أنت تعمل كمساعد ذكاء اصطناعي مدمج داخل تطبيق Lifex-AI Global '
    'Health Network. أي رد تقدّمه هنا يجب أن يفترض أن المستخدم يتفاعل '
    'معك من داخل هذا التطبيق الصحي تحديداً.';

/// تنفيذ عميل ChatGPT (OpenAI) — بنفس نمط GeminiEngineClient.
class OpenAiEngineClient implements ExternalAiEngineClient {
  OpenAiEngineClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, String> _modelByKey = {};

  @override
  ExternalAiProvider get provider => ExternalAiProvider.chatgpt;

  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  @override
  Future<ExternalAiResponse> sendQuery({
    required String query,
    required String apiKeyOrToken,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final model = await _modelFor(apiKeyOrToken);
      if (model == null) {
        return ExternalAiResponse.failure(
          _modelByKey['error:$apiKeyOrToken'] ??
              'المفتاح لم يُرجع نموذجاً من OpenAI.',
        );
      }
      final response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKeyOrToken',
          ...AppAttributionHeader.build(),
          ...?extraHeaders,
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': lifexAiSystemContext},
            {'role': 'user', 'content': query},
          ],
        }),
      );

      if (response.statusCode != 200) {
        return ExternalAiResponse.failure(
          'تعذّر جلب الرد من ChatGPT. ${readProviderError(response.body, response.statusCode)} الربط ما زال محفوظاً.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      final text = choices != null && choices.isNotEmpty
          ? (choices.first['message']?['content'] as String?)
          : null;

      if (text == null) {
        return const ExternalAiResponse.failure(
          'لم يُرجع محرك ChatGPT رداً قابلاً للقراءة.',
        );
      }

      return ExternalAiResponse.success(text);
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'OPENAI_QUERY_FAILED',
        'فشل الاتصال بمحرك ChatGPT.',
        sourceModule: 'ai_service_router',
        exception: e,
        stackTrace: stackTrace,
      );
      return const ExternalAiResponse.failure(
        'حدث خطأ أثناء التواصل مع محرك ChatGPT. الربط ما زال محفوظاً.',
      );
    }
  }

  Future<String?> _modelFor(String apiKeyOrToken) async {
    final cached = _modelByKey[apiKeyOrToken];
    if (cached != null) return cached;
    final response = await _httpClient.get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: {'Authorization': 'Bearer $apiKeyOrToken'},
    );
    if (response.statusCode != 200) {
      _modelByKey['error:$apiKeyOrToken'] =
          'تعذّر قراءة نماذج OpenAI. ${readProviderError(response.body, response.statusCode)}';
      return null;
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    final chosen = chooseOpenAiModelId(data is List ? data : const []);
    if (chosen == null) {
      _modelByKey['error:$apiKeyOrToken'] =
          'قائمة OpenAI بلا نموذج gpt. الربط ما زال محفوظاً.';
      return null;
    }
    _modelByKey[apiKeyOrToken] = chosen;
    return chosen;
  }
}

/// تنفيذ عميل Claude (Anthropic) — بنفس نمط باقي المحركات.
class ClaudeEngineClient implements ExternalAiEngineClient {
  ClaudeEngineClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, String> _modelByKey = {};

  @override
  ExternalAiProvider get provider => ExternalAiProvider.claude;

  static const String _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  Future<ExternalAiResponse> sendQuery({
    required String query,
    required String apiKeyOrToken,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final model = await _modelFor(apiKeyOrToken);
      if (model == null) {
        return ExternalAiResponse.failure(
          _modelByKey['error:$apiKeyOrToken'] ??
              'المفتاح لم يُرجع نموذجاً من Claude.',
        );
      }
      final response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKeyOrToken,
          'anthropic-version': '2023-06-01',
          ...AppAttributionHeader.build(),
          ...?extraHeaders,
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 1024,
          'system': lifexAiSystemContext,
          'messages': [
            {'role': 'user', 'content': query},
          ],
        }),
      );

      if (response.statusCode != 200) {
        return ExternalAiResponse.failure(
          'تعذّر جلب الرد من Claude. ${readProviderError(response.body, response.statusCode)} الربط ما زال محفوظاً.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>?;
      final text = content != null && content.isNotEmpty
          ? (content.first['text'] as String?)
          : null;

      if (text == null) {
        return const ExternalAiResponse.failure(
          'لم يُرجع محرك Claude رداً قابلاً للقراءة.',
        );
      }

      return ExternalAiResponse.success(text);
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'CLAUDE_QUERY_FAILED',
        'فشل الاتصال بمحرك Claude.',
        sourceModule: 'ai_service_router',
        exception: e,
        stackTrace: stackTrace,
      );
      return const ExternalAiResponse.failure(
        'حدث خطأ أثناء التواصل مع محرك Claude. الربط ما زال محفوظاً.',
      );
    }
  }

  Future<String?> _modelFor(String apiKeyOrToken) async {
    final cached = _modelByKey[apiKeyOrToken];
    if (cached != null) return cached;
    final response = await _httpClient.get(
      Uri.parse('https://api.anthropic.com/v1/models'),
      headers: {
        'x-api-key': apiKeyOrToken,
        'anthropic-version': '2023-06-01',
      },
    );
    if (response.statusCode != 200) {
      _modelByKey['error:$apiKeyOrToken'] =
          'تعذّر قراءة نماذج Claude. ${readProviderError(response.body, response.statusCode)}';
      return null;
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    final chosen = chooseClaudeModelId(data is List ? data : const []);
    if (chosen == null) {
      _modelByKey['error:$apiKeyOrToken'] =
          'قائمة Claude بلا نموذج. الربط ما زال محفوظاً.';
      return null;
    }
    _modelByKey[apiKeyOrToken] = chosen;
    return chosen;
  }
}

/// موجّه الخدمة المركزي — يجمع بين UnifiedAiHubGateway (من المستخدم
/// مربوط؟) وعملاء المحركات الفعليين، وينفّذ الاستعلام على المحرك
/// الصحيح تلقائياً.
class AiServiceRouter {
  AiServiceRouter({required this.hubGateway}) {
    // Gemini مسجَّل افتراضياً بوصفه المحرك الأساسي المطلوب من مالك
    // المشروع، بالإضافة لـ ChatGPT وClaude كخيارات إضافية يربطها
    // المستخدم اختيارياً بحسابه الخاص. أي محرك جديد يُسجَّل بنفس
    // الطريقة دون تعديل بقية منطق هذا الصف.
    registerEngineClient(GeminiEngineClient());
    registerEngineClient(OpenAiEngineClient());
    registerEngineClient(ClaudeEngineClient());
  }

  final UnifiedAiHubGateway hubGateway;
  final Map<ExternalAiProvider, ExternalAiEngineClient> _engineClients = {};

  void registerEngineClient(ExternalAiEngineClient client) {
    _engineClients[client.provider] = client;
  }

  /// إرسال استعلام باستخدام المحرك المفضَّل للمستخدم (أو محرك محدَّد
  /// صراحة)، بعد التحقق من وجود حساب مربوط فعلياً لهذا المحرك.
  Future<ExternalAiResponse> query({
    required String profileId,
    required String userQuery,
    ExternalAiProvider? explicitProvider,
  }) async {
    final provider =
        explicitProvider ?? hubGateway.preferredProviderFor(profileId);

    if (provider == null) {
      return const ExternalAiResponse.failure(
        'لم يتم ربط أي محرك ذكاء اصطناعي بعد. يُرجى ربط حساب Gemini أو '
        'أي محرك آخر من الإعدادات أولاً.',
      );
    }

    final client = _engineClients[provider];
    if (client == null) {
      return ExternalAiResponse.failure(
        'المحرك المطلوب (${provider.name}) غير مدعوم داخل التطبيق حالياً.',
      );
    }

    final credential =
        await hubGateway.credentialFor(profileId: profileId, provider: provider);
    if (credential == null) {
      return ExternalAiResponse.failure(
        'لا يوجد حساب مربوط فعلياً بمحرك ${provider.name}. يُرجى ربطه من '
        'الإعدادات أولاً.',
      );
    }

    return client.sendQuery(query: userQuery, apiKeyOrToken: credential);
  }

  /// قائمة المحركات المدعومة برمجياً حالياً داخل التطبيق (بغض النظر عن
  /// كون المستخدم ربط حساباً بها أم لا).
  List<ExternalAiProvider> get supportedEngines => _engineClients.keys.toList();

  /// يفتح جلسة Gemini Live إن وُجد مفتاح صالح ونموذج. لا يعيد المفتاح.
  Future<GeminiBidiVisionSession?> openBlindLiveVision({
    required String profileId,
    LiveSocketConnector? connector,
  }) async {
    final credential = await hubGateway.credentialFor(
      profileId: profileId,
      provider: ExternalAiProvider.gemini,
    );
    if (credential == null || !geminiCredentialUsable(credential)) return null;
    final client = _engineClients[ExternalAiProvider.gemini];
    if (client is! GeminiEngineClient) return null;
    final model = await client.liveModelName(credential);
    if (model == null) return null;
    return GeminiBidiVisionSession.start(
      apiKey: credential,
      model: model,
      connector: connector ?? const IoLiveSocketConnector(),
    );
  }
}
