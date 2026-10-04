/// =============================================================
/// Lifex-AI — الموقع الجغرافي
/// الملف: device_location_service.dart
/// الوصف: خدمة الموقع — تقرأ GPS الجهاز عبر [GeolocationGateway].
/// لا تعرف شيئاً عن geolocator مباشرة. تميز بوضوح بين حالات
/// الفشل (صلاحية، خدمات، إحداثيات غير صحيحة) بدون اختلاق.
/// =============================================================

import 'dart:async';

import 'geolocation_gateway.dart';
import 'location_result.dart';

class DeviceLocationService {
  DeviceLocationService({
    GeolocationGateway? gateway,
    Duration timeout = const Duration(seconds: 30),
  })  : _gateway = gateway ?? const GeolocatorGateway(),
        _timeout = timeout;

  final GeolocationGateway _gateway;
  final Duration _timeout;

  /// طلب صلاحية الموقع من المستخدم. true فقط إذا منحت فعلاً.
  Future<bool> requestLocationPermission() async {
    try {
      return await _gateway.requestPermission() == GeoPerm.granted;
    } catch (_) {
      return false;
    }
  }

  Future<LocationResult> getCurrentLocation() async {
    try {
      switch (await _gateway.checkPermission()) {
        case GeoPerm.granted:
          break;
        case GeoPerm.denied:
          return const FailureLocationResult(
            reason: LocationFailureReason.permissionDenied,
            message: 'Location permission not granted',
          );
        case GeoPerm.deniedForever:
          return const FailureLocationResult(
            reason: LocationFailureReason.permissionPermanentlyDenied,
            message: 'Location permission permanently denied',
          );
        case GeoPerm.unknown:
          return const FailureLocationResult(
            reason: LocationFailureReason.unavailable,
            message: 'Location permission state unknown',
          );
      }

      if (!await _gateway.isLocationServiceEnabled()) {
        return const FailureLocationResult(
          reason: LocationFailureReason.locationServicesDisabled,
          message: 'Location services are disabled',
        );
      }

      final fix = await _gateway
          .getCurrentFix(timeout: _timeout)
          .timeout(_timeout + const Duration(seconds: 5));

      // التحقق من صحة الإحداثيات.
      if (fix.latitude.isNaN ||
          fix.latitude < -90 ||
          fix.latitude > 90) {
        return FailureLocationResult(
          reason: LocationFailureReason.invalidResult,
          message: 'Invalid latitude: ${fix.latitude}',
        );
      }
      if (fix.longitude.isNaN ||
          fix.longitude < -180 ||
          fix.longitude > 180) {
        return FailureLocationResult(
          reason: LocationFailureReason.invalidResult,
          message: 'Invalid longitude: ${fix.longitude}',
        );
      }

      return SuccessLocationResult(
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracy: fix.accuracy,
        timestamp: DateTime.now(),
      );
    } on TimeoutException {
      return FailureLocationResult(
        reason: LocationFailureReason.timeout,
        message:
            'Location acquisition timed out after ${_timeout.inSeconds} seconds',
      );
    } on GeoServiceDisabled {
      return const FailureLocationResult(
        reason: LocationFailureReason.locationServicesDisabled,
        message: 'Location services disabled',
      );
    } on GeoPermissionDenied {
      return const FailureLocationResult(
        reason: LocationFailureReason.permissionDenied,
        message: 'Location permission denied',
      );
    } catch (e) {
      return FailureLocationResult(
        reason: LocationFailureReason.unknown,
        message: 'Unexpected error: $e',
      );
    }
  }
}
