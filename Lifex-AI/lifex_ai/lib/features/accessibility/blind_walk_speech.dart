/// جملة المشي: ما في الإطار أولاً، وبلا قطع للنطق إلا لعائق جديد.
library lifex_ai.features.accessibility.blind_walk_speech;

class BlindWalkSpeech {
  const BlindWalkSpeech._();

  static const _hard = [
    'درج',
    'عائق',
    'سيارة',
    'حافلة',
    'شاحنة',
    'دراجة',
    'إشارة',
    'stair',
    'obstacle',
    'car',
    'bus',
    'truck',
    'bicycle',
    'motorcycle',
    'traffic',
  ];

  /// أسماء التصنيف القصيرة تُقدَّم كإطار. الجمل الجاهزة تبقى كما هي.
  static String line(String raw, {required bool arabic}) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    if (text.contains('\n') ||
        text.contains('.') ||
        text.contains('لن ') ||
        text.contains('ليس ') ||
        text.contains('No ') ||
        text.contains(' not ')) {
      return text;
    }
    if (arabic) return 'في الإطار: $text.';
    return 'In the frame: $text.';
  }

  static String hazardKey(String text) {
    final folded = text.toLowerCase();
    final found = <String>[
      for (final key in _hard)
        if (folded.contains(key.toLowerCase())) key,
    ]..sort();
    return found.join('|');
  }

  static bool hardHazard(String text) => hazardKey(text).isNotEmpty;

  /// true يعني أبقِ الجملة الحالية. مفتاح عائق مختلف يقطعها.
  static bool yieldToCurrentSpeech({
    required bool speaking,
    required String hazardKey,
    required String heardHazardKey,
  }) {
    if (!speaking) return false;
    return hazardKey == heardHazardKey;
  }
}
