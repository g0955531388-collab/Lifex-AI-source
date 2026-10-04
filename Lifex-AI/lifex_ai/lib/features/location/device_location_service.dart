/// =============================================================
/// Lifex-AI — الموقع الجغرافي والطوارئ
/// الملف: device_location_service.dart
/// المسار: lib/features/location/device_location_service.dart
/// الوصف: خدمة الموقع الحقيقية — تحصل على الموقع الجغرافي من
/// نظام Android عبر حزمة geolocator: ^9.0.2. تميز بوضوح بين حالات
/// الفشل المختلفة بدون اختلاق إحداثيات.
/// =============================================================

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'location_result.dart';

/// خدمة الموقع الحقيقية — تحصل على الموقع من GPS الجهاز.
class DeviceLocationService {
  DeviceLocationService({Geolocator? geolocator})
      : _geolocator = geolocator ?? Geolocator();

  final Geolocator _geolocator;

  /// طلب صلاحية الموقع من المستخدم.
  /// تعيد true إذا تم الموافقة، false إذا تم الرفض.
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// الحصول على الموقع الجغرافي الحالي.
  /// تعيد نتيجة تحتوي على الإحداثيات (إن نجحت)
  /// أو تفاصيل الفشل (إن فشلت).
  Future<LocationResult> getCurrentLocation() async {
    try {
      final permission = await Permission.location.status;
      if (permission.isDenied) {
        return FailureLocationResult(
          reason: LocationFailureReason.permissionDenied,
          message: 'User denied location permission',
        );
      }
      if (permission.isPermanentlyDenied) {
        return FailureLocationResult(
          reason: LocationFailureReason.permissionPermanentlyDenied,
          message: 'User permanently denied location permission',
        );
      }

      final serviceEnabled = await _geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return FailureLocationResult(
          reason: LocationFailureReason.locationServicesDisabled,
          message: 'Location services are disabled',
        );
      }

      final position = await _geolocator
          .getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 30),
          )
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw TimeoutException('Location acquisition timeout'),
          );

      if (position == null) {
        return FailureLocationResult(
          reason: LocationFailureReason.invalidResult,
          message: 'Position is null',
        );
      }

      if (position.latitude < -90 || position.latitude > 90) {
        return FailureLocationResult(
          reason: LocationFailureReason.invalidResult,
          message: 'Invalid latitude: ${position.latitude}',
        );
      }
      if (position.longitude < -180 || position.longitude > 180) {
        return FailureLocationResult(
          reason: LocationFailureReason.invalidResult,
          message: 'Invalid longitude: ${position.longitude}',
        );
      }

      return SuccessLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
    } on TimeoutException {
      return FailureLocationResult(
        reason: LocationFailureReason.timeout,
        message: 'Location acquisition timed out after 30 seconds',
      );
    } on LocationServiceDisabledException {
      return FailureLocationResult(
        reason: LocationFailureReason.locationServicesDisabled,
        message: 'Location services disabled exception',
      );
    } on PermissionDeniedException {
      return FailureLocationResult(
        reason: LocationFailureReason.permissionDenied,
        message: 'Permission denied exception',
      );
    } catch (e) {
      return FailureLocationResult(
        reason: LocationFailureReason.unknown,
        message: 'Unexpected error: $e',
      );
    }
  }
}

class TimeoutException implements Exception {
  TimeoutException(this.message);
  final String message;

  @override
  String toString() => 'TimeoutException: $message';
}
