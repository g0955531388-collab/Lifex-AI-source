// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: knowledge_search_tool_test.dart
// المسار: test/core/agent/tools/knowledge_search_tool_test.dart
// الوصف: يختبر KnowledgeSearchTool مع KnowledgeRetriever وهمي (بدون
// أي IO فعلي)، مع التركيز على استنتاج نص البحث من عدة مصادر محتملة
// (query صريح، ثم userRequest، ثم نص مستخرج من ملاحظة سابقة).
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/agent/knowledge/knowledge_document.dart';
import 'package:lifex_ai/core/agent/tools/knowledge_search_tool.dart';
import '../../../support/knowledge_retriever_test_doubles.dart';

AgentContext _context() {
  return AgentContext(
    taskId: 't1',
    profileId: 'p1',
    userRequest: 'عندي صداع',
    permissions: const AgentGrantedPermissions(granted: {}),
  );
}

void main() {
  group('KnowledgeSearchTool.execute — استنتاج نص البحث', () {
    test('يستخدم query الصريح إن وُجد، وليس userRequest', () async {
      final retriever = FakeKnowledgeRetriever(const []);
      final tool = KnowledgeSearchTool(retriever: retriever);

      await tool.execute(
        arguments: const {'query': 'حمى', 'userRequest': 'عندي صداع'},
        context: _context(),
      );

      expect(retriever.lastQuery, 'حمى');
    });

    test('يستخدم userRequest عند غياب query الصريح', () async {
      final retriever = FakeKnowledgeRetriever(const []);
      final tool = KnowledgeSearchTool(retriever: retriever);

      await tool.execute(
        arguments: const {'userRequest': 'عندي صداع'},
        context: _context(),
      );

      expect(retriever.lastQuery, 'عندي صداع');
    });

    test('يستخدم النص المستخرج من ملاحظة سابقة عند غياب كل ما سبق',
        () async {
      final retriever = FakeKnowledgeRetriever(const []);
      final tool = KnowledgeSearchTool(retriever: retriever);

      await tool.execute(
        arguments: const {
          'priorObservations': [
            {'extractedText': 'نتيجة تحليل: سكر مرتفع'}
          ],
        },
        context: _context(),
      );

      expect(retriever.lastQuery, 'نتيجة تحليل: سكر مرتفع');
    });

    test('يفشل بوضوح عند عدم توفر أي نص بحث صالح', () async {
      final retriever = FakeKnowledgeRetriever(const []);
      final tool = KnowledgeSearchTool(retriever: retriever);

      final result = await tool.execute(
        arguments: const {},
        context: AgentContext(
          taskId: 't1',
          profileId: 'p1',
          userRequest: '',
          permissions: const AgentGrantedPermissions(granted: {}),
        ),
      );

      expect(result.isSuccess, isFalse);
    });
  });

  group('KnowledgeSearchTool.execute — نتائج', () {
    test('نتائج فارغة تُنتج ثقة low وليس فشلاً (لا توجد معلومة ≠ خطأ)',
        () async {
      final retriever = FakeKnowledgeRetriever(const []);
      final tool = KnowledgeSearchTool(retriever: retriever);

      final result = await tool.execute(
        arguments: const {'query': 'مرض نادر جداً غير موجود'},
        context: _context(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data['confidence'], 'low');
      expect(result.data['matchCount'], 0);
    });

    test('نتائج موجودة تُنتج ثقة medium', () async {
      const doc = KnowledgeDocument(
        id: 's001',
        sourceFile: 'symptoms_database.json',
        category: 'symptom',
        searchableText: 'صداع',
        raw: {'id': 's001', 'nameAr': 'صداع'},
      );
      final retriever = FakeKnowledgeRetriever(const [doc]);
      final tool = KnowledgeSearchTool(retriever: retriever);

      final result = await tool.execute(
        arguments: const {'query': 'صداع'},
        context: _context(),
      );

      expect(result.data['confidence'], 'medium');
      expect(result.data['matchCount'], 1);
    });
  });
}
