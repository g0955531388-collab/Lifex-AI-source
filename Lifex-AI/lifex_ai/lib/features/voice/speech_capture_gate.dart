/// قرار إغلاق جلسة التعرف. لا يُغلق على حالة فارغة قبل أن تصل الكلمات.
library lifex_ai.features.voice.speech_capture_gate;

class SpeechCaptureGate {
  bool heardListening = false;
  String words = '';
  bool sawFinal = false;
  bool sawError = false;

  void onStatus(String status) {
    if (status == 'listening') heardListening = true;
  }

  void onWords(String incoming, {required bool isFinal}) {
    final trimmed = incoming.trim();
    if (trimmed.isNotEmpty) words = trimmed;
    if (isFinal && words.isNotEmpty) sawFinal = true;
  }

  /// يغلق فوراً فقط بعد أن بدأ الاستماع ووصلت كلمات.
  /// الحالة الفارغة تُمهَل لنتيجة متأخرة.
  bool shouldCloseNow(String status) {
    if (!heardListening) return false;
    if (status != 'done' && status != 'notListening') return false;
    return words.trim().isNotEmpty;
  }

  bool get waitForLateWords =>
      heardListening && words.trim().isEmpty && !sawFinal && !sawError;
}
