/// =============================================================
/// Lifex-AI — الرؤية
/// الملف: camera_rig_policy.dart
/// شرائط صفحة التحكم تُترجم إلى عتاد حقيقي. بلا ×200 ولا 20 ثانية
/// ولا نسبة تيار فلاش ولا سطوع حسّاس مختلق.
/// =============================================================
library lifex_ai.features.vision.camera_rig_policy;

import 'optical_zoom_policy.dart';

/// قيم الصفحات التجريبية. ليست قدرات هذا الهاتف.
class AdvertisedCameraSliders {
  static const zoomMax = 200.0;
  static const exposureSecondsMax = 20.0;
  static const flashPercentMax = 100.0;
  static const shutterUnitMax = 1.0;
  static const previewFactorMax = 2.0;
  static const canvasEdge = 5000;
  static const flashHzMax = 3000;
  static const timerSecondsMax = 15;
}

class CameraRigApply {
  const CameraRigApply({
    required this.zoom,
    required this.exposureOffset,
    required this.torchOn,
    required this.previewBrightness,
    required this.previewContrast,
    required this.messageAr,
  });

  final double zoom;
  final double exposureOffset;
  final bool torchOn;
  final double previewBrightness;
  final double previewContrast;
  final String messageAr;
}

class StudioSliceNote {
  StudioSliceNote({
    required this.id,
    required this.titleAr,
    required this.origin,
    this.path,
    this.visible = true,
  });

  final String id;
  final String titleAr;
  final String origin;
  final String? path;
  bool visible;
}

class StudioSliceBoard {
  final tiles = <StudioSliceNote>[];

  void addCamera({required String path, required double zoom}) {
    tiles.add(
      StudioSliceNote(
        id: 'cam-${tiles.length}',
        titleAr: 'لقطة عدسة ×${zoom.toStringAsFixed(1)}',
        origin: 'camera',
        path: path,
      ),
    );
  }

  void addGallery(String path) {
    tiles.add(
      StudioSliceNote(
        id: 'gal-${tiles.length}',
        titleAr: 'من الاستديو',
        origin: 'gallery',
        path: path,
      ),
    );
  }

  StudioSliceNote? addCrop({
    required double left,
    required double top,
    required double width,
    required double height,
    String? path,
  }) {
    final rect = CameraRigPolicy.normalizeCrop(
      left: left,
      top: top,
      width: width,
      height: height,
    );
    if (rect == null) return null;
    final note = StudioSliceNote(
      id: 'crop-${tiles.length}',
      titleAr:
          'شريحة (${(rect.$3 * 100).round()}×${(rect.$4 * 100).round()}٪)',
      origin: 'crop',
      path: path,
    );
    tiles.add(note);
    return note;
  }

  void toggle(String id, bool visible) {
    for (final tile in tiles) {
      if (tile.id == id) tile.visible = visible;
    }
  }

  bool remove(String id) {
    final index = tiles.indexWhere((tile) => tile.id == id);
    if (index <= 0) return false;
    tiles.removeAt(index);
    return true;
  }
}

class CameraRigPolicy {
  const CameraRigPolicy();

  static const _zoom = OpticalZoomPolicy();

  bool get previewFilterChangesSensor => false;
  bool get cssZoomIsOptical => false;
  bool get advertisedSecondsAreShutter => false;
  bool get flashPercentIsTorchCurrent => false;
  bool get ppmIsCameraRaw => false;

  /// قص منطقة من الإطار ليس تكبيراً بصرياً ×200.
  bool get cropIsOpticalZoom200 => false;

  /// رقم عشوائي على الإطار ليس كشف طوارئ.
  bool get randomFrameIsEmergency => false;

  /// أسماء إضافية على البانر ليست إسناد المشروع.
  bool get extraCreditNamesAllowed => false;

  int clampTimerSeconds(int requested) {
    if (requested < 0) return 0;
    if (requested > AdvertisedCameraSliders.timerSecondsMax) {
      return AdvertisedCameraSliders.timerSecondsMax;
    }
    return requested;
  }

  double clampPreviewFactor(double requested) {
    if (requested < 0) return 0;
    if (requested > AdvertisedCameraSliders.previewFactorMax) {
      return AdvertisedCameraSliders.previewFactorMax;
    }
    return requested;
  }

  double clampZoom({
    required double requested,
    required double minZoom,
    required double maxZoom,
  }) {
    return _zoom.clampToHardware(
      requested: requested,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  /// شريط 0–20 ث أو الغالق 0–1 يمرّ على إزاحة التعريض إن وُجدت.
  double mapAdvertisedToExposureOffset({
    required double advertisedSeconds,
    required double shutterUnit,
    required double minOffset,
    required double maxOffset,
  }) {
    if (maxOffset < minOffset) return minOffset;
    final fromSeconds =
        (advertisedSeconds / AdvertisedCameraSliders.exposureSecondsMax)
            .clamp(0.0, 1.0);
    final fromShutter =
        shutterUnit.clamp(0.0, AdvertisedCameraSliders.shutterUnitMax);
    final t = ((fromSeconds + fromShutter) / 2).clamp(0.0, 1.0);
    return minOffset + t * (maxOffset - minOffset);
  }

  bool torchFromPercent(double percent) => percent > 0;

  /// مصفوفة معاينة. 1 و1 تُبقي الصورة كما خرجت من العدسة.
  List<double> previewColorMatrix({
    required double brightness,
    required double contrast,
  }) {
    final c = clampPreviewFactor(contrast);
    final b = (clampPreviewFactor(brightness) - 1) * 40;
    return <double>[
      c, 0, 0, 0, b,
      0, c, 0, 0, b,
      0, 0, c, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  static (double, double, double, double)? normalizeCrop({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    var l = left;
    var t = top;
    var w = width;
    var h = height;
    if (w < 0) {
      l += w;
      w = -w;
    }
    if (h < 0) {
      t += h;
      h = -h;
    }
    if (w < 0.02 || h < 0.02) return null;
    if (l < 0) l = 0;
    if (t < 0) t = 0;
    if (l + w > 1) w = 1 - l;
    if (t + h > 1) h = 1 - t;
    if (w < 0.02 || h < 0.02) return null;
    return (l, t, w, h);
  }

  CameraRigApply plan({
    required double advertisedZoom,
    required double advertisedExposureSeconds,
    required double advertisedShutter,
    required double advertisedFlashPercent,
    required double advertisedBrightness,
    required double advertisedContrast,
    required double minZoom,
    required double maxZoom,
    required double minExposureOffset,
    required double maxExposureOffset,
    required bool torchAvailable,
    required bool exposureAvailable,
  }) {
    final zoom = clampZoom(
      requested: advertisedZoom,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    final offset = exposureAvailable
        ? mapAdvertisedToExposureOffset(
            advertisedSeconds: advertisedExposureSeconds,
            shutterUnit: advertisedShutter,
            minOffset: minExposureOffset,
            maxOffset: maxExposureOffset,
          )
        : 0.0;
    final torch = torchAvailable && torchFromPercent(advertisedFlashPercent);
    final brightness = clampPreviewFactor(advertisedBrightness);
    final contrast = clampPreviewFactor(advertisedContrast);
    return CameraRigApply(
      zoom: zoom,
      exposureOffset: offset,
      torchOn: torch,
      previewBrightness: brightness,
      previewContrast: contrast,
      messageAr: applyHonestyAr(
        zoom: zoom,
        maxZoom: maxZoom,
        exposureAvailable: exposureAvailable,
        torchAvailable: torchAvailable,
        torchOn: torch,
      ),
    );
  }

  String applyHonestyAr({
    required double zoom,
    required double maxZoom,
    required bool exposureAvailable,
    required bool torchAvailable,
    required bool torchOn,
  }) {
    final zoomLine = _zoom.honestyAr(
      zoom: zoom,
      maxZoom: maxZoom,
      hardwareRead: maxZoom > 0,
    );
    final flashLine = torchAvailable
        ? (torchOn
            ? 'الفلاش ضوء مستمر إن سمح العتاد. ليست نسبة تيار.'
            : 'الفلاش مطفأ.')
        : 'لا ضوء مستمر على هذه العدسة. شريط القوة لا يخترع تياراً.';
    final exposureLine = exposureAvailable
        ? 'زمن التعريض وسرعة الغالق يمرّان من إزاحة العتاد، وليستا ثانيتين.'
        : 'لا إزاحة تعريض على هذه العدسة. لن أؤخر الرسم وأسميه غالقاً.';
    return '$zoomLine $flashLine $exposureLine '
        'السطوع والتباين يغطيان المعاينة فقط، لا يغيّران الحسّاس. '
        'لا قماش 5000×5000 ولا تردد فلاش 3000 هرتز.';
  }

  String refuseCssZoomAr(double hardwareMax) =>
      '×${AdvertisedCameraSliders.zoomMax.round()} في الصفحة التجريبية تكبير واجهة. '
      'سقف هذه العدسة ${hardwareMax.toStringAsFixed(1)}×.';

  String exportHonestyAr() =>
      'الحفظ هو ملف العدسة كما خرج. PPM ليس RAW كاميرا. '
      'تحويل PNG/JPG/WEBP يحتاج مرمّزاً مربوطاً.';

  bool get mapsMasterToFlashHz => false;

  String overlayAlphaHonestyAr() =>
      'شفافية الشريحة العليا للمعاينة. ليست تجسيماً ثلاثياً ولا نيغاتيف تشخيصياً.';

  String stampMarkAr() => 'Lifex-AI system';

  double mapMaster({
    required StudioMasterTarget target,
    required double master,
    required double minZoom,
    required double maxZoom,
  }) {
    final t = (master.clamp(0, 100)) / 100.0;
    switch (target) {
      case StudioMasterTarget.zoom:
        final span = maxZoom - minZoom;
        if (span <= 0) return minZoom;
        return minZoom + t * span;
      case StudioMasterTarget.flash:
        return t * AdvertisedCameraSliders.flashPercentMax;
      case StudioMasterTarget.exposure:
        return t * AdvertisedCameraSliders.exposureSecondsMax;
      case StudioMasterTarget.shutter:
        return t;
      case StudioMasterTarget.brightness:
        return t * AdvertisedCameraSliders.previewFactorMax;
      case StudioMasterTarget.contrast:
        return t * AdvertisedCameraSliders.previewFactorMax;
      case StudioMasterTarget.timer:
        return t * AdvertisedCameraSliders.timerSecondsMax;
    }
  }
}

enum StudioMasterTarget {
  zoom,
  flash,
  exposure,
  shutter,
  brightness,
  contrast,
  timer,
}
