/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: unified_ai_hub_gateway.dart
/// المسار: lib/features/ai/unified_ai_hub_gateway.dart
/// الوصف: بوابة موحّدة تسمح للمستخدم بربط حسابه/مفتاحه الخاص بمحركات
/// ذكاء اصطناعي خارجية متعددة (Gemini كمحرك أساسي، بالإضافة لأي محرك
/// آخر يدعمه لاحقاً)، واختيار أي محرك يريد استخدامه لكل استعلام.
///
/// ⚠️ أمان حرج: مفاتيح API/بيانات الاعتماد يجب ألا تُخزَّن أبداً كنص
/// عادي (plain text) في التخزين العادي. في التنفيذ الفعلي، استخدم حزمة
/// flutter_secure_storage (تخزين مشفَّر على مستوى نظام التشغيل) بدلاً
/// من أي حل تخزين عادي. هذا الملف يوفر البنية المنطقية فقط.
///
/// ⚠️ هذا الملف لا يخزّن أو "يزوّر" أي عدد مستخدمين — عدد المستخدمين
/// الفعلي يُحسب من طرف الخادم الحقيقي عند وجوده، وليس رقماً ثابتاً هنا.
/// =============================================================
library;

import 'dart:convert';

import '../../core/error_handler.dart';

/// محركات الذكاء الاصطناعي الخارجية المدعومة حالياً كهيكل، مع إمكانية
/// إضافة محركات جديدة دون تعديل بنية النظام الأساسية.
enum ExternalAiProvider {
  gemini, // المحرك الأساسي المفضَّل افتراضياً
  chatgpt,
  claude,
  custom, // أي محرك آخر يضيفه المستخدم عبر رابط API عام متوافق
}

/// بيانات اعتماد حساب واحد مربوط بمحرك خارجي معيّن. هذا الكائن يمثّل
/// البنية فقط؛ التخزين الفعلي الآمن يتم عبر طبقة أمان منفصلة.
class ConnectedAiAccount {
  final ExternalAiProvider provider;
  final String accountLabel; // اسم وصفي يختاره المستخدم (مثلاً "حسابي الشخصي")
  final DateTime connectedAt;
  bool isActive;

  ConnectedAiAccount({
    required this.provider,
    required this.accountLabel,
    this.isActive = true,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();
}

/// عقد أي مزوّد اعتماد آمن فعلي (Secure Credential Store)، يُنفَّذ لاحقاً
/// عبر flutter_secure_storage أو ما يعادله.
abstract class SecureCredentialStore {
  Future<void> saveCredential(String key, String value);
  Future<String?> readCredential(String key);
  Future<void> deleteCredential(String key);
}

/// بوابة الذكاء الاصطناعي الموحّدة — نقطة الدخول الوحيدة لإدارة حسابات
/// المستخدم المربوطة بمحركات الذكاء الاصطناعي الخارجية.
class UnifiedAiHubGateway {
  UnifiedAiHubGateway({required this.credentialStore});

  final SecureCredentialStore credentialStore;

  final Map<String, ConnectedAiAccount> _accountsByProfileId = {};
  final Map<String, ExternalAiProvider> _preferredProviderByProfileId = {};

  static const _ledgerKey = 'lifex_ai_linked_ai_accounts_v1';

  /// ربط حساب/مفتاح جديد بمحرك ذكاء اصطناعي معيّن لملف صحي محدد.
  /// المفتاح الفعلي (apiKey) يُخزَّن عبر [credentialStore] الآمن فقط،
  /// ولا يُحفظ أبداً داخل هذا الكائن في الذاكرة كنص دائم.
  Future<bool> connectAccount({
    required String profileId,
    required ExternalAiProvider provider,
    required String accountLabel,
    required String apiKeyOrToken,
  }) async {
    try {
      final credentialKey = _credentialKeyFor(profileId, provider);
      await credentialStore.saveCredential(credentialKey, apiKeyOrToken);

      _accountsByProfileId[_accountKeyFor(profileId, provider)] =
          ConnectedAiAccount(provider: provider, accountLabel: accountLabel);

      // أول محرك يُربط يصبح المفضَّل تلقائياً، وGemini يبقى الافتراضي
      // الموصى به إن لم يُحدَّد المستخدم غيره صراحة.
      _preferredProviderByProfileId.putIfAbsent(profileId, () => provider);
      await _writeLedger();

      return true;
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'AI_HUB_CONNECT_FAILED',
        'فشل ربط حساب محرك الذكاء الاصطناعي: ${provider.name}',
        sourceModule: 'unified_ai_hub_gateway',
        exception: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// فصل حساب مربوط. لا يُستدعى إلا بعد موافقة المستخدم على الشاشة.
  /// فشل البحث أو فشل المحرك لا يمر من هنا.
  Future<void> disconnectAccount({
    required String profileId,
    required ExternalAiProvider provider,
  }) async {
    final accountKey = _accountKeyFor(profileId, provider);
    final removed = _accountsByProfileId.remove(accountKey);
    final wasPreferred = _preferredProviderByProfileId[profileId] == provider;
    if (wasPreferred) {
      _preferredProviderByProfileId.remove(profileId);
    }
    try {
      await _writeLedger();
      await credentialStore.deleteCredential(
        _credentialKeyFor(profileId, provider),
      );
    } catch (e, stackTrace) {
      if (removed != null) {
        _accountsByProfileId[accountKey] = removed;
      }
      if (wasPreferred) {
        _preferredProviderByProfileId[profileId] = provider;
      }
      ErrorHandler.instance.report(
        'AI_HUB_DISCONNECT_KEPT',
        'فشل حذف الربط، فبقي الحساب متصلاً: ${provider.name}',
        sourceModule: 'unified_ai_hub_gateway',
        exception: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// يعيد الربط المحفوظ بعد إعادة تشغيل التطبيق. لا يحذف مفتاحاً.
  Future<void> restoreLinkedAccounts() async {
    final raw = await credentialStore.readCredential(_ledgerKey);
    if (raw == null || raw.trim().isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is! Map) continue;
      final profileId = item['profileId']?.toString() ?? '';
      final providerName = item['provider']?.toString() ?? '';
      final label = item['label']?.toString() ?? '';
      if (profileId.isEmpty || providerName.isEmpty) continue;
      final matches = ExternalAiProvider.values.where(
        (provider) => provider.name == providerName,
      );
      if (matches.isEmpty) continue;
      final provider = matches.first;
      final credential = await credentialStore.readCredential(
        _credentialKeyFor(profileId, provider),
      );
      if (credential == null || credential.isEmpty) continue;
      _accountsByProfileId[_accountKeyFor(profileId, provider)] =
          ConnectedAiAccount(
        provider: provider,
        accountLabel: label.isEmpty ? 'حسابي الشخصي' : label,
        connectedAt: DateTime.tryParse('${item['connectedAt']}') ??
            DateTime.now(),
      );
      _preferredProviderByProfileId.putIfAbsent(profileId, () => provider);
    }
  }

  Future<void> _writeLedger() async {
    final rows = <Map<String, String>>[];
    for (final entry in _accountsByProfileId.entries) {
      final splitAt = entry.key.lastIndexOf('::');
      if (splitAt <= 0) continue;
      rows.add({
        'profileId': entry.key.substring(0, splitAt),
        'provider': entry.value.provider.name,
        'label': entry.value.accountLabel,
        'connectedAt': entry.value.connectedAt.toIso8601String(),
      });
    }
    await credentialStore.saveCredential(_ledgerKey, jsonEncode(rows));
  }

  /// تحديد المحرك المفضَّل الذي سيُستخدم افتراضياً لهذا المستخدم.
  void setPreferredProvider(String profileId, ExternalAiProvider provider) {
    _preferredProviderByProfileId[profileId] = provider;
  }

  ExternalAiProvider? preferredProviderFor(String profileId) =>
      _preferredProviderByProfileId[profileId];

  /// كل الحسابات المربوطة حالياً لملف صحي معيّن.
  List<ConnectedAiAccount> connectedAccountsFor(String profileId) {
    return _accountsByProfileId.entries
        .where((entry) => entry.key.startsWith('$profileId::'))
        .map((entry) => entry.value)
        .toList();
  }

  /// استرجاع بيانات الاعتماد الآمنة لمحرك معيّن (تُستخدم داخلياً فقط
  /// من AiServiceRouter عند تنفيذ استعلام فعلي).
  Future<String?> credentialFor({
    required String profileId,
    required ExternalAiProvider provider,
  }) {
    return credentialStore.readCredential(_credentialKeyFor(profileId, provider));
  }

  String _accountKeyFor(String profileId, ExternalAiProvider provider) =>
      '$profileId::${provider.name}';

  String _credentialKeyFor(String profileId, ExternalAiProvider provider) =>
      'lifex_ai_credential::$profileId::${provider.name}';
}
