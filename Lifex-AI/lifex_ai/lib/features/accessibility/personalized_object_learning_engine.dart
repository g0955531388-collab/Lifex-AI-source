/// =============================================================
/// Lifex-AI — مساعدة المكفوفين وضعاف البصر
/// الملف: personalized_object_learning_engine.dart
/// المسار: lib/features/accessibility/personalized_object_learning_engine.dart
/// الوصف: يسمح للمستخدم بـ"تعليم" الكاميرا التعرّف على أشخاص أو أغراض
/// شخصية مهمة له (مثلاً "هذا ابني أحمد"، "هذا دوائي اليومي")، عبر
/// تصوير الغرض/الشخص وتسجيل اسمه صوتياً مرة واحدة، ليتعرّف عليه
/// التطبيق تلقائياً في المرات القادمة وينطق اسمه.
///
/// ⚠️ خصوصية حساسة: التعرّف على وجوه أشخاص (بما فيهم أفراد العائلة)
/// بيانات بيومترية حساسة. يجب الحصول على موافقة صريحة من المستخدم قبل
/// تفعيل هذه الميزة، وتوضيح أن كل البيانات تُخزَّن محلياً على الجهاز
/// فقط ولا تُرفع لأي خادم خارجي دون موافقة منفصلة صريحة إضافية.
/// =============================================================
library;

import 'assistive_vision_engine.dart';

enum LearnedItemCategory { person, medication, dailyObject, other }

class LearnedItem {
  final String itemId;
  final String labelAr; // الاسم الذي سجّله المستخدم صوتياً ("أحمد")
  final LearnedItemCategory category;
  final List<double> visualEmbedding; // بصمة بصرية مستخرَجة من الصورة
  final DateTime learnedAt;

  LearnedItem({
    required this.itemId,
    required this.labelAr,
    required this.category,
    required this.visualEmbedding,
    DateTime? learnedAt,
  }) : learnedAt = learnedAt ?? DateTime.now();
}

/// عقد أي محرك استخراج/مطابقة بصمة بصرية فعلي.
abstract class VisualEmbeddingModel {
  Future<List<double>> extractEmbedding(List<int> imageBytes);
  double compareEmbeddings(List<double> a, List<double> b);
}

class RecognitionMatch {
  final bool matched;
  final LearnedItem? item;
  final double confidence;

  const RecognitionMatch({
    required this.matched,
    this.item,
    required this.confidence,
  });
}

/// محرك التعلّم الشخصي — يخزّن كل العناصر التي علّمها المستخدم محلياً
/// فقط، ويقارن أي إطار كاميرا جديد بها.
class PersonalizedObjectLearningEngine {
  PersonalizedObjectLearningEngine({required this.embeddingModel});

  final VisualEmbeddingModel embeddingModel;
  final Map<String, List<LearnedItem>> _itemsByProfileId = {};
  int _counter = 0;

  static const double _matchConfidenceThreshold = 0.7;

  void registerWithAssistiveEngine(AssistiveVisionEngine engine) {
    engine.registerHandler(
      AssistiveFeatureType.personalizedRecognition,
      (imageInput, context) async {
        final imageBytes = imageInput as List<int>;
        final profileId = context['profileId'] as String? ?? 'default';
        final match = await recognize(profileId: profileId, imageBytes: imageBytes);

        if (!match.matched) {
          return const AssistiveVisionResult(
            success: true,
            spokenMessageAr: 'لم أتعرّف على هذا الشخص أو الغرض بعد. '
                'يمكنك تعليمي عليه من شاشة الإعدادات.',
          );
        }

        return AssistiveVisionResult(
          success: true,
          spokenMessageAr: 'هذا ${match.item!.labelAr}.',
        );
      },
    );
  }

  /// تعليم عنصر جديد — يستدعيها المستخدم بعد تصوير الشخص/الغرض وتسجيل
  /// اسمه صوتياً (التحويل من صوت لنص يتم عبر speech_to_text_processor.dart
  /// في وحدة الصوت، ويُمرَّر هنا كنص جاهز).
  Future<LearnedItem> learnNewItem({
    required String profileId,
    required List<int> imageBytes,
    required String labelAr,
    required LearnedItemCategory category,
  }) async {
    final embedding = await embeddingModel.extractEmbedding(imageBytes);

    _counter++;
    final item = LearnedItem(
      itemId: 'LRN-$_counter',
      labelAr: labelAr,
      category: category,
      visualEmbedding: embedding,
    );

    _itemsByProfileId.putIfAbsent(profileId, () => []).add(item);
    return item;
  }

  /// التعرّف على إطار كاميرا جديد ومقارنته بكل العناصر المُعلَّمة سابقاً
  /// لنفس المستخدم فقط (لا مقارنة عبر مستخدمين مختلفين إطلاقاً).
  Future<RecognitionMatch> recognize({
    required String profileId,
    required List<int> imageBytes,
  }) async {
    final learnedItems = _itemsByProfileId[profileId] ?? [];
    if (learnedItems.isEmpty) {
      return const RecognitionMatch(matched: false, confidence: 0.0);
    }

    final candidateEmbedding = await embeddingModel.extractEmbedding(imageBytes);

    LearnedItem? bestMatch;
    double bestScore = 0.0;

    for (final item in learnedItems) {
      final score = embeddingModel.compareEmbeddings(
        candidateEmbedding,
        item.visualEmbedding,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    if (bestScore >= _matchConfidenceThreshold && bestMatch != null) {
      return RecognitionMatch(matched: true, item: bestMatch, confidence: bestScore);
    }

    return RecognitionMatch(matched: false, confidence: bestScore);
  }

  /// حذف عنصر مُعلَّم سابقاً (خيار إلزامي في الإعدادات، خصوصاً لصور
  /// الوجوه البيومترية).
  bool forgetItem({required String profileId, required String itemId}) {
    final items = _itemsByProfileId[profileId];
    if (items == null) return false;
    final before = items.length;
    items.removeWhere((i) => i.itemId == itemId);
    return items.length < before;
  }

  List<LearnedItem> learnedItemsFor(String profileId) =>
      List.unmodifiable(_itemsByProfileId[profileId] ?? const []);
}
