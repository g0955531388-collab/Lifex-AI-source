import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_drivers/device_driver_profile.dart';
import 'package:lifex_ai/core/device_drivers/market_catalog_hint.dart';

void main() {
  test('كتالوج السوق تصنيف فقط بلا تعريف ولا تحكم', () {
    final keyboard = MarketCatalogHint.fromRecord({
      'id': 'usb_keyboard_001',
      'type': 'USB',
      'name': 'Generic USB Keyboard',
      'driver': 'drivers/usb/generic_keyboard_driver',
      'supports_bilateral_control': true,
    });
    expect(keyboard.profile, DriverProfiles.computer);
    expect(keyboard.refused, isFalse);
    expect(MarketCatalogHint.controlable, isFalse);
    expect(MarketCatalogHint.bilateralControlAllowed, isFalse);
    expect(MarketCatalogHint.driverPathLoaded, isFalse);
    expect(keyboard.noteAr.contains('drivers/'), isFalse);

    final phone = MarketCatalogHint.fromRecord({
      'type': 'smartphone',
      'name': 'Generic iPhone',
      'driver': 'ios_driver_v1',
      'supports_bilateral_control': true,
    });
    expect(phone.profile, DriverProfiles.phone);
    expect(MarketCatalogHint.bilateralControlAllowed, isFalse);

    final meter = MarketCatalogHint.fromRecord({
      'type': 'Sensor',
      'name': 'Accu-Chek Guide',
    });
    expect(meter.profile, DriverProfiles.medical);
    expect(meter.noteAr, contains('ليست تشخيصاً'));
    expect(MarketCatalogHint.readingIsDiagnosis, isFalse);

    final radio = MarketCatalogHint.fromRecord({
      'type': 'radio_transceiver',
      'name': 'HackRF One',
      'driver': 'hackrf_one_driver',
    });
    expect(radio.refused, isTrue);
    expect(radio.profile, isNull);

    final pump = MarketCatalogHint.fromRecord({
      'name': 'Infusion Pump',
      'type': 'IV Therapy',
    });
    expect(pump.refused, isTrue);

    final lock = MarketCatalogHint.fromRecord({
      'type': 'lock',
      'name': 'August Smart Lock',
      'features': ['lock_unlock', 'remote_control'],
    });
    expect(lock.refused, isTrue);
  });
}
