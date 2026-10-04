/// =============================================================
/// Lifex-AI — الموقع الجغرافي
/// الملف: geolocation_gateway.dart
/// الوصف: واجهة محلية تفصل DeviceLocationService عن geolocator
/// (الإصدار 9)، الذي يستخدم APIs static (لا Geolocator()).
/// التنفيذ الإنتاجي [GeolocatorGateway] يغلف
/// Geolocator.isLocationServiceEnabled() و
/// Geolocator.getCurrentPosition(desiredAccuracy: ...).
/// الاختبارات تستخدم فقط [FakeGateway] على حد المنصة؛
/// منطق DeviceLocationService حقيقي.
/// =============================================================

import 'package:geolocator/geolocator.dart';

/// رقراءة حقيقية من GPS.
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
}

/// الصلاحية (من geolocator).
enum GeoPerm { denied, deniedForever, granted, unknown }

/// خدمات الموقع معطلة.
class GeoServiceDisabled implements Exception {
  const GeoServiceDisabled();
}

/// الصلاحية مرفوضة أثناء القراءة.
class GeoPermissionDenied implements Exception {
  const GeoPermissionDenied();
}

abstract class GeolocationGateway {
  Future<GeoPerm> checkPermission();
  Future<GeoPerm> requestPermission();
  Future<bool> isLocationServiceEnabled();

  /// قد يرمي TimeoutException (dart:async) أو [GeoServiceDisabled]
  /// أو [GeoPermissionDenied].
  Future<GeoFix> getCurrentFix({required Duration timeout});
}

/// التنفيذ الإنتاجي — يستدعي Geolocator APIs static.
class GeolocatorGateway implements GeolocationGateway {
  const GeolocatorGateway();

  static GeoPerm _mapPermission(LocationPermission p) {
    switch (p) {
      case LocationPermission.denied:
        return GeoPerm.denied;
      case LocationPermission.deniedForever:
        return GeoPerm.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return GeoPerm.granted;
      case LocationPermission.unableToDetermine:
        return GeoPerm.unknown;
    }
  }

  @override
  Future<GeoPerm> checkPermission() async =>
      _mapPermission(await Geolocator.checkPermission());

  @override
  Future<GeoPerm> requestPermission() async =>
      _mapPermission(await Geolocator.requestPermission());

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<GeoFix> getCurrentFix({required Duration timeout}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: timeout,
      );
      return GeoFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } on LocationServiceDisabledException {
      throw const GeoServiceDisabled();
    } on PermissionDeniedException {
      throw const GeoPermissionDenied();
    }
  }
}
