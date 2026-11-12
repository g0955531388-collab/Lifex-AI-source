import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/vision/optical_radar_engine.dart';

void main() {
  test('بدون موافقة الكاميرا لا يدّعي مسافة', () {
    final result = OpticalRadarEngine.instance.probe();
    expect(result.success, isFalse);
    expect(result.distanceMeters, isNull);
    expect(result.messageAr, contains('موافقة'));
    expect(result.messageAr, isNot(contains(' متر')));
  });

  test('متر واحد يعود من زمن رحلته المحسوب', () {
    final time = OpticalDistanceEngine.expectedRoundTripTimeSeconds(1);
    expect(time, isNotNull);
    final distance = OpticalDistanceEngine.fromRoundTripTimeSeconds(time!);
    expect(distance, isNotNull);
    expect(distance!.distanceMeters, closeTo(1, 1e-9));
    expect(distance.distanceCentimeters, closeTo(100, 1e-7));
    expect(distance.distanceMillimeters, closeTo(1000, 1e-6));
    expect(
      OpticalDistanceEngine.absoluteErrorMeters(distance.distanceMeters, 1),
      closeTo(0, 1e-9),
    );
  });

  test('زمن غير صالح لا يُنتج مسافة', () {
    expect(OpticalDistanceEngine.fromRoundTripTimeSeconds(-1), isNull);
    expect(OpticalDistanceEngine.fromRoundTripTimeSeconds(double.nan), isNull);
    expect(
      OpticalDistanceEngine.fromRoundTripTimeSeconds(double.infinity),
      isNull,
    );
    expect(OpticalDistanceEngine.expectedRoundTripTimeSeconds(-0.2), isNull);
    expect(OpticalDistanceEngine.absoluteErrorMeters(-1, 1), isNull);
  });

  test('القياس يعمل من زمن مُعطى ويتوقف بلا حسّاس', () {
    expect(OpticalDistanceEngine.simulatedPulseAllowed, isFalse);
    expect(OpticalDistanceEngine.measureDistance(), isNull);
    final time = OpticalDistanceEngine.expectedRoundTripTimeSeconds(2);
    final measured = OpticalDistanceEngine.measureDistance(
      roundTripTimeSeconds: time,
    );
    expect(measured, isNotNull);
    expect(measured!.distanceMeters, closeTo(2, 1e-9));
  });
}
