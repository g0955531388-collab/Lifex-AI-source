/// جملة الصناديق: الاسم ثم الموضع يسار/وسط/يمين. بلا مسافة وبلا أمتار.
library lifex_ai.features.accessibility.blind_box_speech;

import 'blind_camera_speech.dart';
import 'box_geometry.dart';
import 'local_object_detector.dart';

class BlindBoxSpeech {
  const BlindBoxSpeech._();

  static const unknownKey = 'unknown';

  static String placeWord(BoxPlace place, {required bool arabic}) {
    switch (place) {
      case BoxPlace.left:
        return arabic ? 'على اليسار' : 'on the left';
      case BoxPlace.center:
        return arabic ? 'في الوسط' : 'in the center';
      case BoxPlace.right:
        return arabic ? 'على اليمين' : 'on the right';
    }
  }

  static String nameOf(DetectedObject object, String languageCode) {
    final arabic = BlindCameraSpeech.explainsInArabic(languageCode);
    if (!object.known || object.label.trim().isEmpty) {
      return arabic ? 'شيء غير معروف' : 'an unknown object';
    }
    return BlindCameraSpeech.phraseForLabel(object.label, languageCode);
  }

  /// مفتاح وضع المسح: الاسم وحده، فتحرّك الشيء نفسه لا يُعاد نطقه.
  static String keyOf(DetectedObject object) =>
      object.known && object.label.trim().isNotEmpty
          ? object.label.trim().toLowerCase()
          : unknownKey;

  static String line(List<DetectedObject> objects, String languageCode) {
    final boxed = [for (final o in objects) if (o.hasBox) o];
    if (boxed.isEmpty) return '';
    final arabic = BlindCameraSpeech.explainsInArabic(languageCode);
    final parts = [
      for (final o in boxed)
        '${nameOf(o, languageCode)} ${placeWord(o.place, arabic: arabic)}',
    ];
    final body = parts.join(arabic ? '، ' : ', ');
    return arabic ? 'في الإطار: $body.' : 'In the frame: $body.';
  }
}
