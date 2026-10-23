/// وصف أساسي أولاً، والتفاصيل عند الطلب.
/// لا يخترع جنساً ولا حركة ولا مسافة إذا لم يعدها التصنيف.
library lifex_ai.features.accessibility.blind_scene_brief;

import 'blind_camera_speech.dart';
import 'local_object_detector.dart';

class SceneDoubleTap {
  SceneDoubleTap({this.window = const Duration(milliseconds: 400)});

  final Duration window;
  DateTime? _previous;

  /// يعيد true مرة واحدة لكل زوج لمسات داخل المهلة.
  bool register(DateTime now) {
    final previous = _previous;
    _previous = now;
    if (previous == null) return false;
    if (now.difference(previous) <= window) {
      _previous = null;
      return true;
    }
    return false;
  }
}

class SceneHit {
  const SceneHit(this.label, this.confidence);

  final String label;
  final double confidence;
}

class BlindSceneBrief {
  const BlindSceneBrief._();

  /// ما دون هذا الحد لا يُنطق كحقيقة.
  static const speechFloor = 0.5;

  static const noAnalysisAr = 'لم أتمكن من تحليل المشهد بعد، حاول مرة أخرى.';

  static const faceHeldAr =
      'ظهرت تفاصيل دقيقة. لن أبدأ بها. اطلب التفاصيل إن أردت سماعها.';

  static const detailLimitAr =
      'هذا وصف بصري للإطار الحالي. ليس هوية ولا مسافة ولا حالة صحية.';

  static const ocrLimitAr =
      'قارئ النص المثبت يقرأ الحروف اللاتينية. لا أعلن قراءة عربية قبل نموذج يدعمها.';

  static const _detail = {
    'face',
    'smile',
    'teeth',
    'tooth',
    'nail',
    'fingernail',
    'fingernails',
    'hair',
    'eye',
    'eyes',
    'eyebrow',
    'lip',
    'lips',
    'mouth',
    'nose',
    'chin',
    'ear',
    'skin',
    'beard',
    'makeup',
  };

  static List<SceneHit> audibleHits(Iterable<SceneHit> hits) {
    final kept = <SceneHit>[];
    for (final hit in hits) {
      final name = hit.label.trim();
      if (name.isEmpty || hit.confidence < speechFloor) continue;
      kept.add(SceneHit(name, hit.confidence));
    }
    final human = kept.any(
      (hit) => BlindCameraSpeech.humanCue.contains(hit.label.toLowerCase()),
    );
    if (!human) return kept;
    return [
      for (final hit in kept)
        if (!BlindCameraSpeech.dogBesideHuman.contains(hit.label.toLowerCase()))
          hit,
    ];
  }

  static List<String> acceptedLabels(Iterable<SceneHit> hits) {
    return [for (final hit in audibleHits(hits)) hit.label];
  }

  /// وصف من كشف ذي إطار فقط. تسمية بلا صندوق لا تُنطق كجسم.
  static String fromDetections(
    Iterable<DetectedObject> objects, {
    String languageCode = 'ar',
  }) {
    final labels = <String>[];
    for (final object in objects) {
      if (!object.hasBox || object.confidence < speechFloor) continue;
      final name = object.label.trim();
      if (name.isEmpty) continue;
      labels.add(name);
    }
    return primary(labels, languageCode: languageCode);
  }

  static int rank(String label) {
    final key = label.trim().toLowerCase();
    const hazard = {'stairs', 'step', 'traffic light', 'obstacle', 'hole'};
    const person = {
      'person',
      'man',
      'woman',
      'people',
      'human',
      'boy',
      'girl',
      'child',
    };
    const vehicle = {
      'car',
      'vehicle',
      'bus',
      'truck',
      'bicycle',
      'motorcycle',
      'train',
    };
    const place = {'door', 'window', 'building', 'room'};
    const furniture = {'table', 'chair', 'desk', 'couch', 'bed', 'furniture'};
    if (hazard.contains(key)) return 0;
    if (person.contains(key)) return 1;
    if (vehicle.contains(key)) return 2;
    if (place.contains(key)) return 3;
    if (furniture.contains(key)) return 4;
    if (_detail.contains(key)) return 9;
    return 5;
  }

  static String primary(
    Iterable<String> labels, {
    String languageCode = 'ar',
  }) {
    return _namesOnly(labels, languageCode: languageCode);
  }

  static String _namesOnly(
    Iterable<String> labels, {
    required String languageCode,
  }) {
    final arabic = BlindCameraSpeech.explainsInArabic(languageCode);
    final ranked = BlindCameraSpeech.withoutFalseDog(labels)
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    final important = [
      for (final label in ranked)
        if (rank(label) < 9) label,
    ];
    if (important.isEmpty) return '';
    final chosen = important.take(4).toList();
    final names = [
      for (final label in chosen)
        arabic
            ? _leadName(label)
            : BlindCameraSpeech.phraseForLabel(label, languageCode),
    ];
    return names.join(arabic ? '، ' : ', ');
  }

  /// تصنيف الصورة كلها. ليس صندوق جسم ولا مسافة.
  static String classificationSpeech(
    Iterable<SceneHit> hits, {
    String languageCode = 'ar',
  }) {
    return _namesOnly(acceptedLabels(hits), languageCode: languageCode);
  }

  static String _leadName(String label) {
    switch (label.trim().toLowerCase()) {
      case 'person':
      case 'human':
      case 'people':
        return 'شخص';
      case 'man':
        return 'رجل';
      case 'woman':
        return 'امرأة';
      case 'boy':
      case 'girl':
      case 'child':
        return 'طفل';
      case 'car':
        return 'سيارة';
      case 'door':
        return 'باب';
      case 'stairs':
      case 'step':
        return 'درج';
      case 'table':
        return 'طاولة';
      case 'chair':
        return 'كرسي';
      case 'obstacle':
        return 'عائق';
      default:
        return BlindCameraSpeech.phraseForLabel(label, 'ar');
    }
  }

  static String details(
    Iterable<String> labels, {
    required bool hadFrame,
    String languageCode = 'ar',
  }) {
    final arabic = BlindCameraSpeech.explainsInArabic(languageCode);
    if (!hadFrame) return arabic ? noAnalysisAr : 'The scene is not analyzed yet.';
    final names = [
      for (final label in BlindCameraSpeech.withoutFalseDog(labels))
        BlindCameraSpeech.phraseForLabel(label, languageCode),
    ];
    if (names.isEmpty) return arabic ? noAnalysisAr : 'The scene is not analyzed yet.';
    return names.join(arabic ? '، ' : ', ');
  }
}
