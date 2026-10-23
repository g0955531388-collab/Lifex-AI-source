/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: long_term_memory.dart
/// المسار: lib/core/agent/memory/long_term_memory.dart
/// الوصف: ذاكرة طويلة الأمد محكومة بسياسة واضحة (بند 10). لا تُحفظ أي
/// معلومة تلقائياً دون سياسة تصريح صريحة — القاعدة الافتراضية "ارفض"
/// (deny-by-default)، وليس "اسمح إلا إذا استُثني".
/// =============================================================
library;

import 'memory_store.dart';

/// سياسة صريحة لما يُسمح بحفظه في الذاكرة طويلة الأمد. أي فئة بيانات
/// غير مذكورة هنا صراحة تُرفض تلقائياً — هذا يعكس بنود الخصوصية
/// الصارمة في المشروع (لا حفظ بيانات حساسة دون سياسة واضحة).
class LongTermMemoryPolicy {
  const LongTermMemoryPolicy({
    required this.allowedCategories,
    this.enabled = true,
  });

  final bool enabled;
  final Set<String> allowedCategories;

  bool allows(String category) => enabled && allowedCategories.contains(category);

  static const LongTermMemoryPolicy disabled =
      LongTermMemoryPolicy(enabled: false, allowedCategories: {});
}

class LongTermMemory {
  LongTermMemory({
    required AgentMemoryStore store,
    LongTermMemoryPolicy policy = LongTermMemoryPolicy.disabled,
  })  : _store = store,
        _policy = policy;

  final AgentMemoryStore _store;
  LongTermMemoryPolicy _policy;

  LongTermMemoryPolicy get policy => _policy;

  /// تحديث السياسة أثناء التشغيل (مثال: المستخدم يفعّل/يعطّل الذاكرة
  /// من الإعدادات — بند 10: "قابلة للتفعيل/التعطيل").
  void updatePolicy(LongTermMemoryPolicy newPolicy) => _policy = newPolicy;

  Future<bool> remember({
    required String profileId,
    required String category,
    required String key,
    required Map<String, dynamic> value,
  }) async {
    if (!_policy.allows(category)) return false;
    await _store.save(profileId, '$category::$key', value);
    return true;
  }

  Future<Map<String, dynamic>?> recall({
    required String profileId,
    required String category,
    required String key,
  }) {
    return _store.read(profileId, '$category::$key');
  }

  Future<void> forget({
    required String profileId,
    required String category,
    required String key,
  }) {
    return _store.delete(profileId, '$category::$key');
  }

  /// مسح كامل — يُستخدم عند طلب المستخدم الصريح فقط (بند 10: "قابلة
  /// للمسح").
  Future<void> clearAllFor(String profileId) => _store.clearAllFor(profileId);

  /// تصدير كل ما هو محفوظ لهذا المستخدم (بند 10: "قابلة للتصدير").
  Future<Map<String, Map<String, dynamic>?>> exportAllFor(
      String profileId) async {
    final keys = await _store.keysFor(profileId);
    final result = <String, Map<String, dynamic>?>{};
    for (final key in keys) {
      result[key] = await _store.read(profileId, key);
    }
    return result;
  }
}
