/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: conversation_memory.dart
/// المسار: lib/core/agent/memory/conversation_memory.dart
/// الوصف: سجل محادثة قصير محدود الحجم لكل ملف صحي — يُستخدم لبناء
/// AgentContext.conversationContext (بند 11) دون الاحتفاظ بالمحادثة
/// كاملة في الذاكرة إلى الأبد (بند 33: إدارة الذاكرة بعناية على الهاتف).
/// =============================================================
library;

class ConversationTurn {
  const ConversationTurn({
    required this.role, // 'user' | 'assistant'
    required this.text,
    required this.timestamp,
  });

  final String role;
  final String text;
  final DateTime timestamp;
}

class ConversationMemory {
  ConversationMemory({this.maxTurnsPerProfile = 30});

  final int maxTurnsPerProfile;
  final Map<String, List<ConversationTurn>> _turnsByProfile = {};

  void addTurn(String profileId, String role, String text) {
    final turns = _turnsByProfile.putIfAbsent(profileId, () => []);
    turns.add(ConversationTurn(role: role, text: text, timestamp: DateTime.now()));

    // نُبقي فقط آخر N دورة — القديم يُهمَل بدل تراكمه إلى ما لا نهاية.
    if (turns.length > maxTurnsPerProfile) {
      turns.removeRange(0, turns.length - maxTurnsPerProfile);
    }
  }

  List<String> recentTextsFor(String profileId, {int limit = 6}) {
    final turns = _turnsByProfile[profileId] ?? [];
    final recent = turns.length > limit
        ? turns.sublist(turns.length - limit)
        : turns;
    return recent.map((t) => '${t.role}: ${t.text}').toList();
  }

  void clearFor(String profileId) => _turnsByProfile.remove(profileId);
}
