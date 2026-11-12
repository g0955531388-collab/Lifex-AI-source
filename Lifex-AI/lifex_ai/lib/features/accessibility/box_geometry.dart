/// هندسة صناديق الكشف: من الصورة المعتدلة إلى بايتات الحسّاس، والموضع ثلاثي فقط.
/// لا مسافة ولا أمتار.
library lifex_ai.features.accessibility.box_geometry;

import 'dart:math' as math;
import 'dart:typed_data';

enum BoxPlace { left, center, right }

class BoxRect {
  const BoxRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get area => width <= 0 || height <= 0 ? 0 : width * height;

  @override
  bool operator ==(Object other) =>
      other is BoxRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'BoxRect($left, $top, $right, $bottom)';
}

/// ML Kit يعيد الصندوق في إحداثيات الصورة بعد تدويرها معتدلة.
/// هذه الدالة تعيده إلى إحداثيات الإطار الخام كما خرج من الحسّاس.
BoxRect? uprightToSensor(
  BoxRect upright, {
  required int sensorWidth,
  required int sensorHeight,
  required int rotationDegrees,
}) {
  final w = sensorWidth.toDouble();
  final h = sensorHeight.toDouble();
  late BoxRect raw;
  switch (rotationDegrees % 360) {
    case 0:
      raw = upright;
    case 90:
      raw = BoxRect(upright.top, h - upright.right, upright.bottom, h - upright.left);
    case 180:
      raw = BoxRect(w - upright.right, h - upright.bottom, w - upright.left, h - upright.top);
    case 270:
      raw = BoxRect(w - upright.bottom, upright.left, w - upright.top, upright.right);
    default:
      return null;
  }
  final clamped = BoxRect(
    raw.left.clamp(0, w).toDouble(),
    raw.top.clamp(0, h).toDouble(),
    raw.right.clamp(0, w).toDouble(),
    raw.bottom.clamp(0, h).toDouble(),
  );
  if (clamped.area <= 0) return null;
  return clamped;
}

/// عرض الصورة المعتدلة: يتبادل العرض والارتفاع عند 90 و270.
double uprightWidth({
  required int sensorWidth,
  required int sensorHeight,
  required int rotationDegrees,
}) {
  final turned = rotationDegrees % 180 == 90;
  return (turned ? sensorHeight : sensorWidth).toDouble();
}

/// ثلث الإطار الذي يقع فيه مركز الصندوق. العدسة الأمامية تعكس اليمين واليسار.
BoxPlace placeOf(BoxRect upright, double frameWidth, {bool mirrored = false}) {
  if (frameWidth <= 0) return BoxPlace.center;
  var ratio = ((upright.left + upright.right) / 2) / frameWidth;
  ratio = ratio.clamp(0.0, 1.0);
  if (mirrored) ratio = 1 - ratio;
  if (ratio < 1 / 3) return BoxPlace.left;
  if (ratio > 2 / 3) return BoxPlace.right;
  return BoxPlace.center;
}

class Nv21Crop {
  const Nv21Crop(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// يقص NV21 متراصاً على حدود زوجية. القص الأصغر من 16 بكسلاً لا يُسمّى.
Nv21Crop? cropNv21(
  Uint8List nv21, {
  required int width,
  required int height,
  required BoxRect sensorRect,
  int minSide = 16,
}) {
  if (width < 2 || height < 2) return null;
  if (nv21.length < width * height + (width ~/ 2) * (height ~/ 2) * 2) {
    return null;
  }
  int even(num value) => (value.floor() ~/ 2) * 2;
  final left = even(math.max(0, sensorRect.left));
  final top = even(math.max(0, sensorRect.top));
  final right = even(math.min(width.toDouble(), sensorRect.right));
  final bottom = even(math.min(height.toDouble(), sensorRect.bottom));
  final cw = right - left;
  final ch = bottom - top;
  if (cw < minSide || ch < minSide) return null;
  final out = Uint8List(cw * ch + (cw ~/ 2) * (ch ~/ 2) * 2);
  for (var row = 0; row < ch; row++) {
    final from = (top + row) * width + left;
    out.setRange(row * cw, row * cw + cw, nv21, from);
  }
  final chromaStart = width * height;
  var write = cw * ch;
  for (var row = 0; row < ch ~/ 2; row++) {
    final from = chromaStart + ((top ~/ 2) + row) * width + left;
    out.setRange(write, write + cw, nv21, from);
    write += cw;
  }
  return Nv21Crop(out, cw, ch);
}
