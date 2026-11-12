/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: byte_stream_decoder.dart
/// واجهة مفكّك بروتوكول: بايتات متقطعة تدخل، رسائل مكتملة ومتحقق منها تخرج.
/// =============================================================
library lifex_ai.core.device_integration.protocols.byte_stream_decoder;

abstract class ByteStreamDecoder<T> {
  String get protocolName;

  /// يقبل أي تقطيع للبايتات ويعيد ما اكتمل وصحّ منها.
  List<T> feed(List<int> bytes);

  /// رسائل رُفضت (مجموع تحقق خاطئ، طول زائد، صيغة غير صالحة).
  int get rejected;

  void reset();
}
