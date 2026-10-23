/// =============================================================
/// Lifex-AI — قراءة موقع الجهاز
/// بلا نقطة حتى يأذن المستخدم وتكون خدمة الموقع شغّالة.
/// =============================================================
library lifex_ai.features.location.device_location_reader;

import 'package:geolocator/geolocator.dart';

class DeviceFix {
  const DeviceFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

class DeviceLocationRead {
  const DeviceLocationRead({
    required this.messageAr,
    this.fix,
  });

  final DeviceFix? fix;
  final String messageAr;

  bool get hasFix => fix != null;
}

class DeviceLocationReader {
  const DeviceLocationReader();

  Future<DeviceLocationRead> read() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const DeviceLocationRead(
          messageAr: 'خدمة الموقع مطفأة في الجهاز. لم تُخترع نقطة.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const DeviceLocationRead(
          messageAr: 'رُفض إذن الموقع. الاقتراح متوقف.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return DeviceLocationRead(
        fix: DeviceFix(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
        messageAr:
            'قُرئ موقع الجهاز: ${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}.',
      );
    } catch (error) {
      return DeviceLocationRead(
        messageAr: 'تعذّرت قراءة الموقع. $error',
      );
    }
  }
}
