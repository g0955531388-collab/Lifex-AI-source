// =============================================================
// Lifex-AI — اختبارات الموقع الجغرافي
// يستخدم FakeGateway عند حد المنصة فقط؛ منطق
// DeviceLocationService حقيقي. بدون GPS وهمي.
// =============================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/location/device_location_service.dart';
import 'package:lifex_ai/features/location/geolocation_gateway.dart';
import 'package:lifex_ai/features/location/location_result.dart';

class FakeGateway implements GeolocationGateway {
  GeoPerm permission = GeoPerm.granted;
  GeoPerm requestResult = GeoPerm.granted;
  bool serviceEnabled = true;
  Object? fixError;
  GeoFix? fix = const GeoFix(latitude: 33.5, longitude: 36.3, accuracy: 8);

  int requestCalls = 0;
  int fixCalls = 0;

  @override
  Future<GeoPerm> checkPermission() async => permission;

  @override
  Future<GeoPerm> requestPermission() async {
    requestCalls++;
    return requestResult;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<GeoFix> getCurrentFix({required Duration timeout}) async {
    fixCalls++;
    if (fixError != null) throw fixError!;
    return fix!;
  }
}

void main() {
  late FakeGateway gateway;
  late DeviceLocationService service;

  setUp(() {
    gateway = FakeGateway();
    service = DeviceLocationService(gateway: gateway);
  });

  FailureLocationResult expectFailure(
      LocationResult r, LocationFailureReason why) {
    expect(r, isA<FailureLocationResult>());
    final f = r as FailureLocationResult;
    expect(f.reason, why);
    return f;
  }

  group('getCurrentLocation', () {
    test('returns the real fix from the gateway', () async {
      final r = await service.getCurrentLocation();
      expect(r, isA<SuccessLocationResult>());
      final s = r as SuccessLocationResult;
      expect(s.latitude, 33.5);
      expect(s.longitude, 36.3);
      expect(s.accuracy, 8);
      expect(s.isFresh, isTrue);
    });

    test('permission denied: no fix is requested', () async {
      gateway.permission = GeoPerm.denied;
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.permissionDenied);
      expect(gateway.fixCalls, 0);
      expect(gateway.requestCalls, 0);
    });

    test('permission permanently denied is reported', () async {
      gateway.permission = GeoPerm.deniedForever;
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.permissionPermanentlyDenied);
      expect(gateway.fixCalls, 0);
    });

    test('unknown permission state is unavailable, not a guess', () async {
      gateway.permission = GeoPerm.unknown;
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.unavailable);
    });

    test('location services disabled', () async {
      gateway.serviceEnabled = false;
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.locationServicesDisabled);
      expect(gateway.fixCalls, 0);
    });

    test('timeout', () async {
      gateway.fixError = TimeoutException('gps');
      expectFailure(
          await service.getCurrentLocation(), LocationFailureReason.timeout);
    });

    test('services disabled during fix read', () async {
      gateway.fixError = const GeoServiceDisabled();
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.locationServicesDisabled);
    });

    test('permission revoked during fix read', () async {
      gateway.fixError = const GeoPermissionDenied();
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.permissionDenied);
    });

    test('invalid latitude is rejected', () async {
      gateway.fix = const GeoFix(latitude: 150, longitude: 0);
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.invalidResult);
    });

    test('invalid longitude is rejected', () async {
      gateway.fix = const GeoFix(latitude: 0, longitude: 200);
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.invalidResult);
    });

    test('NaN latitude is rejected', () async {
      gateway.fix = GeoFix(latitude: double.nan, longitude: 0);
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.invalidResult);
    });

    test('NaN longitude is rejected', () async {
      gateway.fix = GeoFix(latitude: 0, longitude: double.nan);
      expectFailure(await service.getCurrentLocation(),
          LocationFailureReason.invalidResult);
    });

    test('unexpected exception becomes unknown', () async {
      gateway.fixError = StateError('boom');
      final f = expectFailure(
          await service.getCurrentLocation(), LocationFailureReason.unknown);
      expect(f.message, contains('boom'));
    });
  });

  group('requestLocationPermission', () {
    test('true when granted', () async {
      expect(await service.requestLocationPermission(), isTrue);
      expect(gateway.requestCalls, 1);
    });

    test('false when denied', () async {
      gateway.requestResult = GeoPerm.denied;
      expect(await service.requestLocationPermission(), isFalse);
    });
  });
}
