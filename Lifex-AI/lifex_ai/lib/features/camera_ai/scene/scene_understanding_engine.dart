/// وصف مكاني من عناصر لها صندوق. حجم الصندوق حجم في الإطار، لا أمتار.
/// فراغ الوسط ليس طريقاً مفتوحاً.
library lifex_ai.features.camera_ai.scene.scene_understanding_engine;

/// المنطقة الأفقية داخل إطار الكاميرا.
enum SpatialZone { left, center, right }

/// ما يمكن نسبه إلى عنصر مكشوف. بلا ادّعاء حريق أو سلك أو مسافة.
enum SceneCategory {
  sidewalk,
  road,
  person,
  vehicle,
  stairs,
  door,
  furniture,
  obstacleGeneric,
  other,
}

/// عنصر واحد له موضع أفقي وصندوق.
class SceneElement {
  const SceneElement({
    required this.labelAr,
    required this.category,
    required this.zone,
    required this.confidence,
    this.sizeRatio = 0.0,
  });

  final String labelAr;
  final SceneCategory category;
  final SpatialZone zone;
  final double confidence;

  /// مساحة الصندوق نسبة إلى الإطار، من 0 إلى 1.
  final double sizeRatio;

  /// حجم ظاهر في الإطار. ليس قرباً مقاساً.
  String get frameSizeAr {
    if (sizeRatio > 0.35) return 'كبير في الإطار';
    if (sizeRatio > 0.15) return 'متوسط في الإطار';
    if (sizeRatio > 0.05) return 'صغير في الإطار';
    return 'صغير جداً في الإطار';
  }
}

/// وصف المشهد الجاهز للنطق.
class SceneLayout {
  const SceneLayout({required this.elements, required this.spokenSummaryAr});

  final List<SceneElement> elements;
  final String spokenSummaryAr;
}

/// يبني جملة لكل منطقة من أكبر عنصر مقبول فيها.
class SceneUnderstandingEngine {
  const SceneUnderstandingEngine({this.minConfidence = 0.55});

  final double minConfidence;

  static const _zoneAr = {
    SpatialZone.left: 'على يسارك',
    SpatialZone.center: 'في وسط الإطار',
    SpatialZone.right: 'على يمينك',
  };

  SceneLayout buildLayout(List<SceneElement> rawElements) {
    final accepted = rawElements
        .where((element) => element.confidence >= minConfidence)
        .toList()
      ..sort((a, b) => b.sizeRatio.compareTo(a.sizeRatio));

    final parts = <String>[];
    for (final zone in SpatialZone.values) {
      SceneElement? chosen;
      for (final element in accepted) {
        if (element.zone == zone) {
          chosen = element;
          break;
        }
      }
      if (chosen == null) continue;
      parts.add(
        '${chosen.labelAr} ${_zoneAr[zone]} (${chosen.frameSizeAr})',
      );
    }

    return SceneLayout(
      elements: accepted,
      spokenSummaryAr: parts.isEmpty
          ? 'لا أرى عناصر واضحة في هذا الاتجاه.'
          : '${parts.join('، ')}.',
    );
  }
}
