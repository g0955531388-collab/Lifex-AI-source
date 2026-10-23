/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: adaptive_learning_engine.dart
/// المسار: lib/features/education/adaptive_learning_engine.dart
/// الوصف: تعديل صعوبة/وتيرة المحتوى التدريبي بناءً على أداء المتعلم في
/// اختبارات قصيرة متتالية — منطق تكيّف بسيط وشفاف قائم على عتبات نتائج.
/// =============================================================
library;

enum DifficultyLevel { beginner, intermediate, advanced }

class QuizAttempt {
  final String courseId;
  final double scoreRatio; // 0.0 - 1.0
  final DateTime attemptedAt;

  QuizAttempt({
    required this.courseId,
    required this.scoreRatio,
    DateTime? attemptedAt,
  }) : attemptedAt = attemptedAt ?? DateTime.now();
}

/// محرك التعليم التكيفي.
class AdaptiveLearningEngine {
  AdaptiveLearningEngine();

  final Map<String, List<QuizAttempt>> _attemptsByLearner = {};
  final Map<String, DifficultyLevel> _currentLevelByLearner = {};

  static const double _advanceThreshold = 0.85;
  static const double _regressThreshold = 0.5;

  DifficultyLevel currentLevelFor(String learnerId) =>
      _currentLevelByLearner[learnerId] ?? DifficultyLevel.beginner;

  /// تسجيل محاولة اختبار جديدة، وتعديل مستوى الصعوبة تلقائياً حسب
  /// النتيجة — أداء ممتاز يرفع المستوى، وأداء ضعيف يخفّضه.
  DifficultyLevel recordAttemptAndAdapt({
    required String learnerId,
    required QuizAttempt attempt,
  }) {
    _attemptsByLearner.putIfAbsent(learnerId, () => []).add(attempt);

    final currentLevel = currentLevelFor(learnerId);

    if (attempt.scoreRatio >= _advanceThreshold &&
        currentLevel != DifficultyLevel.advanced) {
      final nextLevel = DifficultyLevel.values[currentLevel.index + 1];
      _currentLevelByLearner[learnerId] = nextLevel;
      return nextLevel;
    }

    if (attempt.scoreRatio < _regressThreshold &&
        currentLevel != DifficultyLevel.beginner) {
      final previousLevel = DifficultyLevel.values[currentLevel.index - 1];
      _currentLevelByLearner[learnerId] = previousLevel;
      return previousLevel;
    }

    return currentLevel;
  }

  List<QuizAttempt> historyFor(String learnerId) =>
      List.unmodifiable(_attemptsByLearner[learnerId] ?? const []);
}
