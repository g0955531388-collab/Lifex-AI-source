/// يطوي نطق التعرف حتى تُطابق الهمزة والتاء المربوطة والتشكيل النص المحفوظ.
library lifex_ai.features.voice.spoken_fold;

const List<int> _tashkeel = [
  0x064B,
  0x064C,
  0x064D,
  0x064E,
  0x064F,
  0x0650,
  0x0651,
  0x0652,
  0x0670,
  0x0640,
];

const String _droppedMarks = '؟?!.,،;؛:\'"«»“”()[]…';

/// نص واحد للمقارنة. لا يُستخدم لقص كلمة التنبيه لأن الطول قد يتغيّر.
String foldSpoken(String raw) {
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final unit in raw.toLowerCase().codeUnits) {
    if (_tashkeel.contains(unit)) continue;
    if (unit <= 32) {
      pendingSpace = buffer.isNotEmpty;
      continue;
    }
    final ch = String.fromCharCode(unit);
    if (_droppedMarks.contains(ch)) continue;
    int mapped = unit;
    switch (unit) {
      case 0x0622: // آ
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0671: // ٱ
        mapped = 0x0627;
        break;
      case 0x0649: // ى
      case 0x0626: // ئ
        mapped = 0x064A;
        break;
      case 0x0629: // ة
        mapped = 0x0647;
        break;
      case 0x0624: // ؤ
        mapped = 0x0648;
        break;
    }
    if (pendingSpace) {
      buffer.write(' ');
      pendingSpace = false;
    }
    buffer.writeCharCode(mapped);
  }
  return buffer.toString();
}

bool spokenContains(String foldedUtterance, String needle) {
  final key = foldSpoken(needle);
  return key.isNotEmpty && foldedUtterance.contains(key);
}
