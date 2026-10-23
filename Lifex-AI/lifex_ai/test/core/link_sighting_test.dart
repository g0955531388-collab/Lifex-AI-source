import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/connectivity/link_sighting.dart';

void main() {
  test('الظهور على كل أنواع الربط يبقى مشاهدة', () {
    final ledger = LinkSightingLedger();
    expect(LinkSightingLedger.appliesToEveryLink, isTrue);
    expect(ConnectionType.values, contains(ConnectionType.network));
    expect(ConnectionType.values, contains(ConnectionType.usb));
    expect(ConnectionType.values, contains(ConnectionType.bluetooth));
    expect(ConnectionType.values, contains(ConnectionType.wifi));

    for (final link in ConnectionType.values) {
      final seen = ledger.note(link, 'device-${link.name}', label: link.name);
      expect(seen.connected, isFalse);
      expect(seen.authenticated, isFalse);
      expect(seen.authorized, isFalse);
      expect(seen.controlable, isFalse);
      expect(seen.readingIsMeasurement, isFalse);
    }

    expect(ledger.all, hasLength(ConnectionType.values.length));
    expect(ledger.all.every((item) => item.connected), isFalse);
  });

  test('جهاز موثوق ظاهر على USB أو واي فاي لا يُربط وحده', () {
    final ledger = LinkSightingLedger();
    final seen = ledger.noteTrustedCandidates(
      link: ConnectionType.usb,
      seenIds: ['usb-1', 'usb-2'],
      trustedIds: ['usb-1'],
    );
    final wifi = ledger.note(ConnectionType.wifi, 'net-a');
    expect(LinkSightingLedger.autoConnectOnSightingAllowed, isFalse);
    expect(seen, hasLength(1));
    expect(seen.single.deviceId, 'usb-1');
    expect(seen.single.connected, isFalse);
    expect(wifi.connected, isFalse);
    expect(ledger.find(ConnectionType.usb, 'usb-2'), isNull);
  });

  test('بدء البحث عن السواقة يسجّل الظهور فقط', () {
    final ledger = LinkSightingLedger();
    final seen = ledger.startDriverQuery(
      ConnectionType.usb,
      ' USB_PID_1234 ',
    );
    expect(LinkSightingLedger.remoteDriverDownloadAllowed, isFalse);
    expect(LinkSightingLedger.dynamicDriverLoadAllowed, isFalse);
    expect(seen.deviceId, 'USB_PID_1234');
    expect(seen.label, 'driver-query');
    expect(seen.connected, isFalse);
    expect(seen.authorized, isFalse);
    expect(seen.controlable, isFalse);
    expect(seen.readingIsMeasurement, isFalse);
  });
}
