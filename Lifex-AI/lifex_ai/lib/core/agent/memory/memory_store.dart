/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: memory_store.dart
/// المسار: lib/core/agent/memory/memory_store.dart
/// الوصف: عقد تخزين مجرد للذاكرة طويلة الأمد. لا يُنفَّذ هنا تخزين فعلي
/// على القرص — المشروع يملك بالفعل Hive (انظر pubspec.yaml) لذا يُترك
/// الربط الفعلي لـ Adapter منفصل خارج هذه الطبقة (اتساقاً مع بند 39:
/// "أنشئ abstraction حقيقياً... وضع Adapter واضحاً"). التنفيذ الافتراضي
/// هنا In-Memory فقط، آمن للاستخدام فوراً دون كسر شيء، ويمكن استبداله
/// لاحقاً بـ HiveMemoryStore دون تعديل أي كود يستخدم هذا العقد.
/// =============================================================
library;

abstract class AgentMemoryStore {
  Future<void> save(String profileId, String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> read(String profileId, String key);
  Future<void> delete(String profileId, String key);
  Future<List<String>> keysFor(String profileId);
  Future<void> clearAllFor(String profileId);
}

/// تنفيذ افتراضي آمن في الذاكرة فقط (لا يبقى بين جلسات التطبيق).
/// يُستخدم كقيمة افتراضية حتى يُوصَّل Adapter حقيقي (مثل Hive) من
/// composition root المشروع (نفس نمط main.dart لبقية المديرين).
class InMemoryAgentMemoryStore implements AgentMemoryStore {
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  @override
  Future<void> save(
      String profileId, String key, Map<String, dynamic> value) async {
    _store.putIfAbsent(profileId, () => {});
    _store[profileId]![key] = value;
  }

  @override
  Future<Map<String, dynamic>?> read(String profileId, String key) async {
    return _store[profileId]?[key];
  }

  @override
  Future<void> delete(String profileId, String key) async {
    _store[profileId]?.remove(key);
  }

  @override
  Future<List<String>> keysFor(String profileId) async {
    return _store[profileId]?.keys.toList() ?? [];
  }

  @override
  Future<void> clearAllFor(String profileId) async {
    _store.remove(profileId);
  }
}
