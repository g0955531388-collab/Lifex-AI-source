/// =============================================================
/// Lifex-AI — الرؤية
/// الملف: optical_radar_engine.dart
/// المسار: lib/features/vision/optical_radar_engine.dart
/// الوصف: رادار ضوئي. قياس زمن الرحلة يحتاج حسّاس ToF.
/// المعادلة تحوّل زمناً مُعطى إلى مسافة، ولا تقيس الزمن ولا تتحكم بالكاميرا.
/// =============================================================
library lifex_ai.features.vision.optical_radar_engine;

import '../../core/permission_transparency.dart';
import 'omnisense_desk.dart';

class OpticalRadarResult {
  const OpticalRadarResult({
    required this.success,
    required this.messageAr,
    this.distanceMeters,
  });

  final bool success;
  final String messageAr;
  final double? distanceMeters;
}

class OpticalRadarEngine {
  OpticalRadarEngine._internal();
  static final OpticalRadarEngine instance = OpticalRadarEngine._internal();

  OpticalRadarResult probe() {
    final permissions = PermissionTransparencyManager.instance;
    if (!permissions.isGranted(LifexSensitivePermission.camera)) {
      return const OpticalRadarResult(
        success: false,
        messageAr:
            'الرادار الضوئي يحتاج موافقة الكاميرا والفلاش من شاشة شفافية الصلاحيات أولاً.',
      );
    }
    permissions.recordOf(LifexSensitivePermission.camera)?.recordUsage();
    return OpticalRadarResult(
      success: false,
      messageAr: OmniSenseDesk.absentDepth().spokenAr,
    );
  }
}

/// مسافة محسوبة من زمن رحلة مُعطى. ليست قراءة حسّاس.
class OpticalDistanceResult {
  const OpticalDistanceResult({
    required this.roundTripTimeSeconds,
    required this.distanceMeters,
  });

  final double roundTripTimeSeconds;
  final double distanceMeters;

  double get distanceCentimeters => distanceMeters * 100.0;

  double get distanceMillimeters => distanceMeters * 1000.0;
}

/// تحويل زمن الذهاب والعودة إلى مسافة. الزمن يأتي من خارج هذا الملف.
class OpticalDistanceEngine {
  const OpticalDistanceEngine._();

  static const speedOfLightMetersPerSecond = 299792458.0;

  /// نبضة عشوائية أو تأخير مبرمج لا يُحسبان زمناً.
  static const simulatedPulseAllowed = false;

  /// تعمل بالمعادلة إن وُجد زمن رحلة. بلا زمن لا تُعاد مسافة.
  static OpticalDistanceResult? measureDistance({double? roundTripTimeSeconds}) {
    if (roundTripTimeSeconds == null) return null;
    return fromRoundTripTimeSeconds(roundTripTimeSeconds);
  }

  static OpticalDistanceResult? fromRoundTripTimeSeconds(
    double roundTripTimeSeconds,
  ) {
    if (!roundTripTimeSeconds.isFinite || roundTripTimeSeconds < 0) {
      return null;
    }
    final distance =
        speedOfLightMetersPerSecond * roundTripTimeSeconds / 2.0;
    if (!distance.isFinite) return null;
    return OpticalDistanceResult(
      roundTripTimeSeconds: roundTripTimeSeconds,
      distanceMeters: distance,
    );
  }

  static double? expectedRoundTripTimeSeconds(double distanceMeters) {
    if (!distanceMeters.isFinite || distanceMeters < 0) return null;
    return 2.0 * distanceMeters / speedOfLightMetersPerSecond;
  }

  /// فرق مطلق بين مسافتين. مقارنة حسابية، وليست شهادة دقة للحسّاس.
  static double? absoluteErrorMeters(
    double calculatedDistanceMeters,
    double referenceDistanceMeters,
  ) {
    if (!calculatedDistanceMeters.isFinite ||
        !referenceDistanceMeters.isFinite ||
        calculatedDistanceMeters < 0 ||
        referenceDistanceMeters < 0) {
      return null;
    }
    return (calculatedDistanceMeters - referenceDistanceMeters).abs();
  }
}
