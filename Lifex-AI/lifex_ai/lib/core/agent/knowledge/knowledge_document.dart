/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: knowledge_document.dart
/// المسار: lib/core/agent/knowledge/knowledge_document.dart
/// الوصف: تمثيل موحّد لأي "وحدة معرفة" مفهرسة بعد استخراجها من ملفات
/// lib/data/medical/*.json (مرض، عرض، دواء، تحليل، أو قاعدة ربط). هذا
/// الشكل الموحّد يسمح لـ KnowledgeRetriever بالبحث عبر كل الملفات
/// الخمسة بمنطق واحد بدل منطق مختلف لكل ملف.
/// =============================================================
library;

class KnowledgeDocument {
  const KnowledgeDocument({
    required this.id,
    required this.sourceFile,
    required this.category,
    required this.searchableText,
    required this.raw,
  });

  final String id;

  /// اسم ملف JSON المصدر (مثال: 'diseases_database.json') — يُستخدم في
  /// ReportAgent لإضافة "مصادر البيانات" (بند 14/38).
  final String sourceFile;

  /// نوع الوحدة: disease | symptom | medication | test | knowledgeLink
  final String category;

  /// نص مُجمَّع من الحقول القابلة للبحث (الاسم العربي، المرادفات...)
  /// يُستخدم فقط للفهرسة والمطابقة، وليس للعرض المباشر.
  final String searchableText;

  /// البيانات الأصلية كما وردت من JSON — تُستخدم عند بناء السياق
  /// النهائي المُرسَل للوكيل المتخصص.
  final Map<String, dynamic> raw;
}
