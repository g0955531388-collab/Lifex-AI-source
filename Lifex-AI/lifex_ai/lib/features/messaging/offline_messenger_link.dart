/// إرسال بلا إنترنت. المسودة والمشاركة تُفتحان على الجهاز.
/// البلوتوث والواي فاي والكابل يُسألان، ولا تُحسب الرسالة واصلة
/// إلا إذا قبل الناقل البايتات. قبول البايتات ليس إيصالاً من الطرف الآخر
/// ولا تأكيداً من خادم.
library lifex_ai.features.messaging.offline_messenger_link;

import '../../core/connectivity/connection_device.dart';
import '../../core/connectivity/connection_state.dart';
import '../../core/connectivity/connection_type.dart';
import '../../core/connectivity/wired/serial_connection.dart';
import '../../core/connectivity/wired/usb_connection.dart';
import '../../core/connectivity/wireless/bluetooth/bluetooth_manager.dart';
import '../../core/connectivity/wireless/wifi/wifi_manager.dart';
import 'phone_messenger_desk.dart';

enum OfflineChannel { sms, shareSheet, bluetooth, wifi, wifiDirect, cable }

class OfflineChannelAttempt {
  const OfflineChannelAttempt({
    required this.channel,
    required this.handoffOpened,
    required this.bytesAccepted,
    required this.phraseKey,
  });

  final OfflineChannel channel;
  final bool handoffOpened;

  /// الناقل قبل البايتات. ليس وصولاً إلى هاتف الآخر.
  final bool bytesAccepted;
  final String phraseKey;
}

class OfflineMessengerResult {
  const OfflineMessengerResult({required this.attempts});

  final List<OfflineChannelAttempt> attempts;

  bool get serverDeliveryConfirmed => false;

  bool get peerReceiptConfirmed => false;

  bool get anyHandoffOpened => attempts.any((item) => item.handoffOpened);
}

class OfflineMessengerLink {
  const OfflineMessengerLink({
    BluetoothManager? bluetooth,
    WifiConnection? wifi,
    WifiDirectManager? wifiDirect,
    UsbConnection? usb,
    SerialConnection? serial,
  })  : _bluetooth = bluetooth,
        _wifi = wifi,
        _wifiDirect = wifiDirect,
        _usb = usb,
        _serial = serial;

  final BluetoothManager? _bluetooth;
  final WifiConnection? _wifi;
  final WifiDirectManager? _wifiDirect;
  final UsbConnection? _usb;
  final SerialConnection? _serial;

  Future<OfflineMessengerResult> send({
    required String phone,
    required String message,
    required Future<bool> Function({
      required String phone,
      required String body,
    }) openSmsDraft,
    required Future<bool> Function(String text) openShareSheet,
  }) async {
    final body = message.trim();
    if (body.isEmpty) {
      return const OfflineMessengerResult(
        attempts: [
          OfflineChannelAttempt(
            channel: OfflineChannel.sms,
            handoffOpened: false,
            bytesAccepted: false,
            phraseKey: 'empty',
          ),
        ],
      );
    }
    final attempts = <OfflineChannelAttempt>[];
    final digits = PhoneMessengerDesk.digitsOf(phone);
    if (digits.isEmpty) {
      attempts.add(const OfflineChannelAttempt(
        channel: OfflineChannel.sms,
        handoffOpened: false,
        bytesAccepted: false,
        phraseKey: 'phoneShort',
      ));
    } else {
      final opened = await openSmsDraft(phone: digits, body: body);
      attempts.add(OfflineChannelAttempt(
        channel: OfflineChannel.sms,
        handoffOpened: opened,
        bytesAccepted: false,
        phraseKey: opened ? 'smsDraftOpened' : 'smsDraftFailed',
      ));
    }

    var shared = false;
    try {
      shared = await openShareSheet(body);
    } catch (_) {
      shared = false;
    }
    attempts.add(OfflineChannelAttempt(
      channel: OfflineChannel.shareSheet,
      handoffOpened: shared,
      bytesAccepted: false,
      phraseKey: shared ? 'shareSheetOpened' : 'shareSheetFailed',
    ));

    attempts.add(await _bluetoothAttempt());
    attempts.add(await _wifiAttempt(body));
    attempts.add(await _wifiDirectAttempt());
    attempts.add(await _cableAttempt(body));
    return OfflineMessengerResult(attempts: attempts);
  }

  Future<OfflineChannelAttempt> _bluetoothAttempt() async {
    final manager = _bluetooth ?? UnboundBluetoothManager();
    try {
      final found = await manager.discover();
      if (found.isEmpty) {
        return const OfflineChannelAttempt(
          channel: OfflineChannel.bluetooth,
          handoffOpened: false,
          bytesAccepted: false,
          phraseKey: 'bluetoothUnbound',
        );
      }
      final state = await manager.connect(found.first);
      return OfflineChannelAttempt(
        channel: OfflineChannel.bluetooth,
        handoffOpened: state == ConnectionState.connected,
        bytesAccepted: false,
        phraseKey: state == ConnectionState.connected
            ? 'bluetoothSeenNoReceipt'
            : 'bluetoothUnbound',
      );
    } catch (_) {
      return const OfflineChannelAttempt(
        channel: OfflineChannel.bluetooth,
        handoffOpened: false,
        bytesAccepted: false,
        phraseKey: 'bluetoothUnbound',
      );
    }
  }

  Future<OfflineChannelAttempt> _wifiAttempt(String body) async {
    final wifi = _wifi ?? UnboundWifiConnection();
    try {
      final result = await wifi.send(body.codeUnits);
      return OfflineChannelAttempt(
        channel: OfflineChannel.wifi,
        handoffOpened: false,
        bytesAccepted: result.accepted,
        phraseKey: result.accepted ? 'linkAcceptedNoReceipt' : 'wifiUnbound',
      );
    } catch (_) {
      return const OfflineChannelAttempt(
        channel: OfflineChannel.wifi,
        handoffOpened: false,
        bytesAccepted: false,
        phraseKey: 'wifiUnbound',
      );
    }
  }

  Future<OfflineChannelAttempt> _wifiDirectAttempt() async {
    final direct = _wifiDirect ?? const WifiDirectManager();
    try {
      final state = await direct.connectPeer('');
      return OfflineChannelAttempt(
        channel: OfflineChannel.wifiDirect,
        handoffOpened: state == ConnectionState.connected,
        bytesAccepted: false,
        phraseKey: state == ConnectionState.connected
            ? 'linkAcceptedNoReceipt'
            : 'wifiUnbound',
      );
    } catch (_) {
      return const OfflineChannelAttempt(
        channel: OfflineChannel.wifiDirect,
        handoffOpened: false,
        bytesAccepted: false,
        phraseKey: 'wifiUnbound',
      );
    }
  }

  Future<OfflineChannelAttempt> _cableAttempt(String body) async {
    final usb = _usb ?? UnboundUsbConnection();
    final serial = _serial ?? UnboundSerialConnection();
    try {
      final usbResult = await usb.send(body.codeUnits);
      final serialResult = await serial.write(body.codeUnits);
      final accepted = usbResult.accepted || serialResult.accepted;
      return OfflineChannelAttempt(
        channel: OfflineChannel.cable,
        handoffOpened: false,
        bytesAccepted: accepted,
        phraseKey: accepted ? 'linkAcceptedNoReceipt' : 'cableUnbound',
      );
    } catch (_) {
      return const OfflineChannelAttempt(
        channel: OfflineChannel.cable,
        handoffOpened: false,
        bytesAccepted: false,
        phraseKey: 'cableUnbound',
      );
    }
  }
}

/// جهاز مسبار للاختبار. الإنتاج لا يمرّر اسماً مخترعاً كطرف متصل.
ConnectionDevice offlineProbeDevice({
  required String id,
  required ConnectionType type,
  bool virtual = true,
}) {
  return ConnectionDevice(
    id: id,
    name: id,
    connectionType: type,
    state: ConnectionState.disconnected,
    virtual: virtual,
  );
}
