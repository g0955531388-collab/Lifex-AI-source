import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_box_speech.dart';
import 'package:lifex_ai/features/accessibility/box_geometry.dart';
import 'package:lifex_ai/features/accessibility/local_object_detector.dart';

void main() {
  test('upright boxes map back to the sensor frame for every quarter turn', () {
    const box = BoxRect(10, 20, 30, 60);
    expect(
      uprightToSensor(box, sensorWidth: 100, sensorHeight: 80, rotationDegrees: 0),
      box,
    );
    expect(
      uprightToSensor(box, sensorWidth: 100, sensorHeight: 80, rotationDegrees: 90),
      const BoxRect(20, 50, 60, 70),
    );
    expect(
      uprightToSensor(box, sensorWidth: 100, sensorHeight: 80, rotationDegrees: 180),
      const BoxRect(70, 20, 90, 60),
    );
    expect(
      uprightToSensor(box, sensorWidth: 100, sensorHeight: 80, rotationDegrees: 270),
      const BoxRect(40, 10, 80, 30),
    );
    expect(
      uprightToSensor(box, sensorWidth: 100, sensorHeight: 80, rotationDegrees: 45),
      isNull,
    );
  });

  test('upright width swaps on quarter turns', () {
    expect(uprightWidth(sensorWidth: 640, sensorHeight: 480, rotationDegrees: 90), 480);
    expect(uprightWidth(sensorWidth: 640, sensorHeight: 480, rotationDegrees: 0), 640);
  });

  test('place is a third of the frame and the front lens mirrors it', () {
    expect(placeOf(const BoxRect(0, 0, 60, 10), 300), BoxPlace.left);
    expect(placeOf(const BoxRect(120, 0, 180, 10), 300), BoxPlace.center);
    expect(placeOf(const BoxRect(240, 0, 300, 10), 300), BoxPlace.right);
    expect(placeOf(const BoxRect(0, 0, 60, 10), 300, mirrored: true), BoxPlace.right);
  });

  test('NV21 crop keeps luma and chroma on even edges', () {
    const w = 8, h = 8;
    final nv21 = Uint8List(w * h + w * h ~/ 2);
    for (var i = 0; i < w * h; i++) {
      nv21[i] = i;
    }
    for (var i = 0; i < w * h ~/ 2; i++) {
      nv21[w * h + i] = 200 + (i % 50);
    }
    final crop = cropNv21(
      nv21,
      width: w,
      height: h,
      sensorRect: const BoxRect(2, 2, 6, 6),
      minSide: 2,
    )!;
    expect(crop.width, 4);
    expect(crop.height, 4);
    expect(crop.bytes.sublist(0, 4), [18, 19, 20, 21]);
    expect(crop.bytes.length, 4 * 4 + 4 * 2);
    expect(crop.bytes[16], nv21[w * h + 1 * w + 2]);
    expect(
      cropNv21(nv21, width: w, height: h, sensorRect: const BoxRect(0, 0, 4, 4)),
      isNull,
    );
  });

  test('box speech says name and place, unknown stays unknown, no meters', () {
    const chair = DetectedObject(
      label: 'Chair',
      confidence: 0.8,
      left: 0,
      top: 0,
      right: 10,
      bottom: 10,
      place: BoxPlace.left,
    );
    const thing = DetectedObject(
      label: '',
      confidence: 0,
      left: 0,
      top: 0,
      right: 10,
      bottom: 10,
      place: BoxPlace.right,
      known: false,
    );
    final ar = BlindBoxSpeech.line(const [chair, thing], 'ar');
    expect(ar, 'في الإطار: كرسي على اليسار، شيء غير معروف على اليمين.');
    final en = BlindBoxSpeech.line(const [chair, thing], 'en');
    expect(en, 'In the frame: Chair on the left, an unknown object on the right.');
    expect(ar.contains('متر'), isFalse);
    expect(BlindBoxSpeech.keyOf(chair), 'chair');
    expect(BlindBoxSpeech.keyOf(thing), BlindBoxSpeech.unknownKey);
  });
}
