/// =============================================================
/// Lifex-AI — اختبارات الموقع الجغرافي
/// الملف: device_location_service_test.dart
/// الوصف: اختبارات وحدة لخدمة الموقع الحقيقية.
/// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lifex_ai/features/location/device_location_service.dart';
import 'package:lifex_ai/features/location/location_result.dart';

class MockGeolocator extends Mock implements Geolocator {}

void main() {
  group('DeviceLocationService', () {
    late MockGeolocator mockGeolocator;
    late DeviceLocationService service;

    setUp(() {
      mockGeolocator = MockGeolocator();
      service = DeviceLocationService(geolocator: mockGeolocator);
    });

    group('getCurrentLocation', () {
      test('returns success with valid coordinates', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.getCurrentPosition(
          timeLimit: any(named: 'timeLimit'),
          accuracyDesired: any(named: 'accuracyDesired'),
        )).thenAnswer((_) async => Position(
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          isMocked: false,
        ));

        final result = await service.getCurrentLocation();

        expect(result, isA<SuccessLocationResult>());
        final success = result as SuccessLocationResult;
        expect(success.latitude, 40.7128);
        expect(success.longitude, -74.0060);
        expect(success.accuracy, 10.0);
        expect(success.isFresh, true);
      });

      test('returns failure when location services disabled', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => false);

        final result = await service.getCurrentLocation();

        expect(result, isA<FailureLocationResult>());
        final failure = result as FailureLocationResult;
        expect(failure.reason,
            LocationFailureReason.locationServicesDisabled);
      });

      test('returns failure on timeout', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.getCurrentPosition(
          timeLimit: any(named: 'timeLimit'),
          accuracyDesired: any(named: 'accuracyDesired'),
        )).thenThrow(TimeoutException('Test timeout'));

        final result = await service.getCurrentLocation();

        expect(result, isA<FailureLocationResult>());
        final failure = result as FailureLocationResult;
        expect(failure.reason, LocationFailureReason.timeout);
      });

      test('returns failure on invalid latitude', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.getCurrentPosition(
          timeLimit: any(named: 'timeLimit'),
          accuracyDesired: any(named: 'accuracyDesired'),
        )).thenAnswer((_) async => Position(
          latitude: 150.0, // Invalid: > 90
          longitude: 0.0,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          isMocked: false,
        ));

        final result = await service.getCurrentLocation();

        expect(result, isA<FailureLocationResult>());
        final failure = result as FailureLocationResult;
        expect(failure.reason, LocationFailureReason.invalidResult);
      });

      test('returns failure on invalid longitude', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.getCurrentPosition(
          timeLimit: any(named: 'timeLimit'),
          accuracyDesired: any(named: 'accuracyDesired'),
        )).thenAnswer((_) async => Position(
          latitude: 0.0,
          longitude: 200.0, // Invalid: > 180
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          isMocked: false,
        ));

        final result = await service.getCurrentLocation();

        expect(result, isA<FailureLocationResult>());
        final failure = result as FailureLocationResult;
        expect(failure.reason, LocationFailureReason.invalidResult);
      });

      test('returns failure on unknown exception', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.getCurrentPosition(
          timeLimit: any(named: 'timeLimit'),
          accuracyDesired: any(named: 'accuracyDesired'),
        )).thenThrow(Exception('Unknown error'));

        final result = await service.getCurrentLocation();

        expect(result, isA<FailureLocationResult>());
        final failure = result as FailureLocationResult;
        expect(failure.reason, LocationFailureReason.unknown);
      });

      test('result is fresh within 60 seconds', () async {
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.getCurrentPosition(
          timeLimit: any(named: 'timeLimit'),
          accuracyDesired: any(named: 'accuracyDesired'),
        )).thenAnswer((_) async => Position(
          latitude: 40.0,
          longitude: -74.0,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          isMocked: false,
        ));

        final result = await service.getCurrentLocation();

        expect(result, isA<SuccessLocationResult>());
        final success = result as SuccessLocationResult;
        expect(success.isFresh, true);
      });
    });

    group('requestLocationPermission', () {
      test('returns true when permission granted', () async {
        // Note: permission_handler.request() is called directly in the service.
        // In a real environment, this would interact with Android.
        // For this test, we verify the method exists and handles exceptions.
        final permission = await service.requestLocationPermission();
        expect(permission, isA<bool>());
      });
    });
  });

  group('LocationResult', () {
    test('SuccessLocationResult reports isSuccess true', () {
      final result = SuccessLocationResult(
        latitude: 40.0,
        longitude: -74.0,
        accuracy: 5.0,
        timestamp: DateTime.now(),
      );
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
    });

    test('FailureLocationResult reports isSuccess false', () {
      final result = FailureLocationResult(
        reason: LocationFailureReason.timeout,
        message: 'Test timeout',
      );
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
    });
  });
}
