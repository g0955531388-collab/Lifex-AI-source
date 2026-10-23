/// =============================================================
/// Lifex-AI — الهوية الصحية والملفات الشخصية
/// الملف: family_genetic_engine.dart
/// المسار: lib/features/profile/family_genetic_engine.dart
/// الوصف: محرك العلاقات العائلية والوراثية — يبني شجرة عائلية صحية
/// ويستخلص أنماط الأمراض الوراثية المحتملة من تاريخ العائلة، لدعم
/// الذكاء الاصطناعي والأطباء في التقييم الوقائي.
/// =============================================================
library;

import 'health_profile.dart';

/// نوع صلة القرابة بين ملفين صحيين.
enum RelationType {
  parentOf,
  childOf,
  siblingOf,
  spouseOf,
  grandparentOf,
  grandchildOf,
  other,
}

/// علاقة قرابة واحدة موجّهة بين ملفين (من → إلى).
class FamilyRelation {
  final String fromProfileId;
  final String toProfileId;
  final RelationType relation;

  const FamilyRelation({
    required this.fromProfileId,
    required this.toProfileId,
    required this.relation,
  });

  Map<String, dynamic> toJson() => {
        'fromProfileId': fromProfileId,
        'toProfileId': toProfileId,
        'relation': relation.name,
      };

  factory FamilyRelation.fromJson(Map<String, dynamic> json) => FamilyRelation(
        fromProfileId: json['fromProfileId'] as String,
        toProfileId: json['toProfileId'] as String,
        relation: RelationType.values.firstWhere(
          (e) => e.name == json['relation'],
          orElse: () => RelationType.other,
        ),
      );
}

/// نتيجة تحليل الاستعداد الوراثي لحالة صحية معينة داخل العائلة.
class GeneticRiskInsight {
  final String conditionName;

  /// عدد أفراد العائلة (من الدرجة الأولى والثانية) المصابين بنفس الحالة.
  final int affectedRelativesCount;

  /// وصف نصي مبسّط لمستوى الاهتمام المطلوب — هذا **ليس تشخيصاً**، بل
  /// إشارة إحصائية بسيطة يجب أن تُعرض دائماً مصحوبة بتوصية مراجعة طبيب.
  final String note;

  const GeneticRiskInsight({
    required this.conditionName,
    required this.affectedRelativesCount,
    required this.note,
  });
}

/// محرك العلاقات العائلية والوراثية.
///
/// يعمل هذا المحرك فوق MultiProfileEngine ويحتاج قائمة الملفات الصحية
/// نفسها (health_profile.dart) لقراءة سجلات الحالات المزمنة منها،
/// دون أن يمتلك نسخة خاصة بها.
class FamilyGeneticEngine {
  FamilyGeneticEngine();

  final List<FamilyRelation> _relations = [];

  List<FamilyRelation> get relations => List.unmodifiable(_relations);

  /// إضافة علاقة قرابة جديدة بين ملفين. تُضاف تلقائياً العلاقة العكسية
  /// المنطقية عندما يكون ذلك واضحاً (أب/ابن، أخ/أخ).
  void addRelation(FamilyRelation relation) {
    _relations.add(relation);

    final inverse = _inverseOf(relation);
    if (inverse != null) {
      _relations.add(inverse);
    }
  }

  FamilyRelation? _inverseOf(FamilyRelation r) {
    switch (r.relation) {
      case RelationType.parentOf:
        return FamilyRelation(
          fromProfileId: r.toProfileId,
          toProfileId: r.fromProfileId,
          relation: RelationType.childOf,
        );
      case RelationType.childOf:
        return FamilyRelation(
          fromProfileId: r.toProfileId,
          toProfileId: r.fromProfileId,
          relation: RelationType.parentOf,
        );
      case RelationType.grandparentOf:
        return FamilyRelation(
          fromProfileId: r.toProfileId,
          toProfileId: r.fromProfileId,
          relation: RelationType.grandchildOf,
        );
      case RelationType.grandchildOf:
        return FamilyRelation(
          fromProfileId: r.toProfileId,
          toProfileId: r.fromProfileId,
          relation: RelationType.grandparentOf,
        );
      case RelationType.siblingOf:
        return FamilyRelation(
          fromProfileId: r.toProfileId,
          toProfileId: r.fromProfileId,
          relation: RelationType.siblingOf,
        );
      case RelationType.spouseOf:
        return FamilyRelation(
          fromProfileId: r.toProfileId,
          toProfileId: r.fromProfileId,
          relation: RelationType.spouseOf,
        );
      case RelationType.other:
        return null;
    }
  }

  /// كل الأقارب المباشرين (درجة أولى) لملف معيّن.
  List<String> firstDegreeRelativesOf(String profileId) {
    return _relations
        .where((r) =>
            r.fromProfileId == profileId &&
            (r.relation == RelationType.parentOf ||
                r.relation == RelationType.childOf ||
                r.relation == RelationType.siblingOf))
        .map((r) => r.toProfileId)
        .toSet()
        .toList();
  }

  /// تحليل بسيط للاستعداد الوراثي بناءً على الحالات المزمنة المسجّلة
  /// لدى الأقارب من الدرجة الأولى. هذا تحليل إحصائي أولي فقط، وليس بديلاً
  /// عن استشارة وراثية طبية متخصصة.
  List<GeneticRiskInsight> analyzeFamilyRisk({
    required String profileId,
    required Map<String, HealthProfile> allProfilesById,
  }) {
    final relativeIds = firstDegreeRelativesOf(profileId);
    final Map<String, int> conditionCounts = {};

    for (final relativeId in relativeIds) {
      final relativeProfile = allProfilesById[relativeId];
      if (relativeProfile == null) continue;

      for (final condition in relativeProfile.chronicConditions) {
        conditionCounts.update(
          condition.conditionName,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return conditionCounts.entries.map((entry) {
      final note = entry.value >= 2
          ? 'وُجد أكثر من قريب من الدرجة الأولى مصاب بهذه الحالة — يُنصح بمناقشة الأمر مع الطبيب المختص.'
          : 'وُجد قريب واحد من الدرجة الأولى مصاب بهذه الحالة — معلومة للاطلاع فقط.';
      return GeneticRiskInsight(
        conditionName: entry.key,
        affectedRelativesCount: entry.value,
        note: note,
      );
    }).toList();
  }
}
