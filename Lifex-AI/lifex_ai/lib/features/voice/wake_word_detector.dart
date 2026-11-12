/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: wake_word_detector.dart
/// نداء التطبيق كما يعيشه المتحدث: ليفكس / Lifex، مع طيّ التشكيل.
/// صياغة مستقلة، ليست نقلاً عن ملفات كوتلن أو قوالب جاهزة.
/// =============================================================
library lifex_ai.features.voice.wake_word_detector;

/// الاستماع الدائم غير مبني. الخدمة الأمامية الحالية إشعار فقط.
class WakeListenLimit {
  const WakeListenLimit();

  bool get continuousWhileScreenOff => false;

  String get requirementAr =>
      'كلمة التنبيه المستمرة تحتاج خدمة أمامية بنوع ميكروفون وإشعاراً دائماً '
      'وإذناً صريحاً. أندرويد قد يوقفها مع الشاشة المقفلة، وهي تستهلك البطارية. '
      'غير مفعّلة في هذا البناء.';
}

class WakeWordDetector {
  WakeWordDetector({this.customWakeWord = 'ليفكس'});

  String customWakeWord;

  static const List<int> _tashkeel = [
    0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0670,
  ];

  String fold(String raw) {
    final buffer = StringBuffer();
    for (final unit in raw.toLowerCase().codeUnits) {
      if (_tashkeel.contains(unit)) continue;
      switch (unit) {
        case 0x0622: // آ
        case 0x0623: // أ
        case 0x0625: // إ
          buffer.writeCharCode(0x0627); // ا
          break;
        case 0x0649: // ى
          buffer.writeCharCode(0x064A); // ي
          break;
        case 0x0629: // ة
          buffer.writeCharCode(0x0647); // ه
          break;
        default:
          buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  List<String> _cues() {
    final chosen = customWakeWord.trim();
    final set = <String>{'ليفكس', 'lifex', 'يا ليفكس', 'hey lifex'};
    if (chosen.isNotEmpty) {
      set.add(chosen);
      set.add(chosen.toLowerCase());
    }
    return set.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  bool containsWakeWord(String raw) {
    final folded = fold(raw);
    for (final cue in _cues()) {
      if (folded.contains(fold(cue))) return true;
    }
    return false;
  }

  /// يُسقط نداء التطبيق من بداية الجملة ويُبقي الأمر كما نُطق.
  String strip(String raw) {
    var text = raw.trim();
    final foldedHead = fold(text);
    for (final cue in _cues()) {
      final foldedCue = fold(cue);
      if (!foldedHead.startsWith(foldedCue)) continue;
      final cut = _cutOriginalPrefix(text, cue.length);
      return _trimLeadingSeparators(cut);
    }
    return text;
  }

  String _cutOriginalPrefix(String original, int cueCharCount) {
    var seen = 0;
    var index = 0;
    while (index < original.length && seen < cueCharCount) {
      final unit = original.codeUnitAt(index);
      if (!_tashkeel.contains(unit)) seen++;
      index++;
    }
    return original.substring(index);
  }

  String _trimLeadingSeparators(String text) {
    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (ch.trim().isEmpty || '،,:-;'.contains(ch)) {
        i++;
        continue;
      }
      break;
    }
    return text.substring(i).trim();
  }
}
