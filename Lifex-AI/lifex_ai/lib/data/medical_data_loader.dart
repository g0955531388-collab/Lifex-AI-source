/// =============================================================
/// Lifex-AI Global Health Network
/// الملف: medical_data_loader.dart
/// المسار: lib/data/medical_data_loader.dart
/// الوصف: يبني الخرائط الجاهزة التي يحتاجها AiBridge من محتوى
/// symptoms_database.json وmedical_knowledge.json، بعد قراءتهما عبر
/// MedicalDatabaseManager — وليس مباشرة من rootBundle — حتى يستفيد
/// الذكاء الاصطناعي تلقائياً من أي تحديث للحزمة الطبية يُنزَّل من
/// الخادم، دون أي تغيير في هذا الملف.
/// =============================================================
library;

import 'medical_database_manager.dart';
import 'medical_json_link_module.dart';

/// نتيجة تحميل كل البيانات الطبية اللازمة لتهيئة محركات الذكاء
/// الاصطناعي عبر AiBridge.initialize().
class LoadedMedicalKnowledge {
  final Map<String, String> symptomKeywordMap;
  final Set<String> emergencySymptomIds;
  final Map<String, String> symptomBodySystemMap;
  final MedicalJsonLinkIndex linkIndex;

  const LoadedMedicalKnowledge({
    required this.symptomKeywordMap,
    required this.emergencySymptomIds,
    required this.symptomBodySystemMap,
    required this.linkIndex,
  });
}

/// محمّل البيانات الطبية — يبني الخرائط النهائية فوق ما يُرجعه
/// MedicalDatabaseManager (سواء كانت نسخة الأصول الافتراضية أو نسخة
/// محدَّثة من الخادم).
class MedicalDataLoader {
  MedicalDataLoader._();

  /// تحميل وبناء كل الخرائط اللازمة لتهيئة الذكاء الاصطناعي الصحي
  /// دفعة واحدة عند إقلاع التطبيق.
  static Future<LoadedMedicalKnowledge> loadAll(
    MedicalDatabaseManager databaseManager,
  ) async {
    final bundle = await databaseManager.readFullBundle();
    final symptomsJson = bundle[MedicalBundleFiles.symptoms] ?? const {};
    final knowledgeJson = bundle[MedicalBundleFiles.knowledge] ?? const {};
    Map<String, dynamic>? biometricCatalog;
    try {
      biometricCatalog = await databaseManager.readBundleFile(
        MedicalBundleFiles.biometrics,
      );
    } catch (_) {
      biometricCatalog = null;
    }

    final symptomKeywordMap = _buildSymptomKeywordMap(symptomsJson);
    final symptomBodySystemMap = _buildSymptomBodySystemMap(symptomsJson);
    final emergencySymptomIds = _buildEmergencySymptomIds(knowledgeJson);
    final linkIndex = const MedicalJsonLinkModule().build(
      bundle: bundle,
      biometricCatalog: biometricCatalog,
    );

    return LoadedMedicalKnowledge(
      symptomKeywordMap: symptomKeywordMap,
      emergencySymptomIds: emergencySymptomIds,
      symptomBodySystemMap: symptomBodySystemMap,
      linkIndex: linkIndex,
    );
  }

  /// بناء خريطة: الاسم العربي للعرض → معرّف العرض. تُستخدم من
  /// HealthAnalysisEngine لمطابقة كلمات المستخدم بمعرّفات ثابتة.
  static Map<String, String> _buildSymptomKeywordMap(
    Map<String, dynamic> symptomsJson,
  ) {
    final symptoms = symptomsJson['symptoms'] as List<dynamic>? ?? [];
    final map = <String, String>{};

    for (final entry in symptoms) {
      final symptom = entry as Map<String, dynamic>;
      final nameAr = symptom['nameAr'] as String?;
      final id = symptom['id'] as String?;
      if (nameAr != null && id != null) {
        map[nameAr] = id;
      }
    }
    return map;
  }

  /// بناء خريطة: معرّف العرض → النظام الجسدي (bodySystem)، تُستخدم من
  /// DoctorGuidanceEngine لتحديد التخصص المناسب.
  static Map<String, String> _buildSymptomBodySystemMap(
    Map<String, dynamic> symptomsJson,
  ) {
    final symptoms = symptomsJson['symptoms'] as List<dynamic>? ?? [];
    final map = <String, String>{};

    for (final entry in symptoms) {
      final symptom = entry as Map<String, dynamic>;
      final id = symptom['id'] as String?;
      final bodySystem = symptom['bodySystem'] as String?;
      if (id != null && bodySystem != null) {
        map[id] = bodySystem;
      }
    }
    return map;
  }

  /// استخراج معرّفات الأعراض الحرجة من قواعد التصعيد الموجودة في
  /// medical_knowledge.json (emergencyEscalationRules).
  static Set<String> _buildEmergencySymptomIds(
    Map<String, dynamic> knowledgeJson,
  ) {
    final rules =
        knowledgeJson['emergencyEscalationRules'] as List<dynamic>? ?? [];
    final ids = <String>{};

    for (final entry in rules) {
      final rule = entry as Map<String, dynamic>;
      final triggerIds = rule['triggerSymptomIds'] as List<dynamic>? ?? [];
      for (final id in triggerIds) {
        ids.add(id as String);
      }
    }
    return ids;
  }
}
