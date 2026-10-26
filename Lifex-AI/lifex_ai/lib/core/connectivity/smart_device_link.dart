/// بحث عن جهاز ظاهر على قناة مربوطة.
/// الاكتشاف ليس اتصالاً ولا تحكماً.
/// الجهاز الذي له اسم أو هوية مؤكدة بخصوصية: لا اتجاهين قبل موافقته.
library lifex_ai.core.connectivity.smart_device_link;

import 'connection_device.dart';
import 'connection_state.dart';
import 'device_discovery.dart';
import 'transport.dart';

class SmartDeviceLinkOffer {
  const SmartDeviceLinkOffer({
    required this.device,
    required this.requiresPrivacy,
    required this.peerConsent,
    required this.outboundAccepted,
    required this.inboundSeen,
    required this.noteAr,
  });

  final ConnectionDevice device;
  final bool requiresPrivacy;
  final bool peerConsent;
  final bool outboundAccepted;
  final bool inboundSeen;
  final String noteAr;

  /// الاتجاهان وقعا. هذا ليس حالة CONTROLABLE.
  bool get exchanged =>
      outboundAccepted && inboundSeen && (!requiresPrivacy || peerConsent);
}

class SmartDeviceLink {
  SmartDeviceLink({DeviceDiscovery? discovery})
      : _discovery = discovery ?? DeviceDiscovery();

  final DeviceDiscovery _discovery;

  bool requiresPrivacy(ConnectionDevice device) {
    if (device.virtual) return false;
    return device.identityConfirmed || device.name.trim().isNotEmpty;
  }

  Future<List<SmartDeviceLinkOffer>> search() async {
    final found = await _discovery.scan(
      usb: true,
      bluetooth: true,
      ble: true,
      wifi: true,
      nfc: true,
      includeVirtual: false,
    );
    return [
      for (final device in found)
        SmartDeviceLinkOffer(
          device: device,
          requiresPrivacy: requiresPrivacy(device),
          peerConsent: false,
          outboundAccepted: false,
          inboundSeen: false,
          noteAr: device.state == ConnectionState.unbound
              ? 'القناة غير مربوطة. الجهاز مكتشف فقط وليس متصلاً.'
              : 'مكتشف فقط. إن كان بخصوصية فالاتجاهان ينتظران موافقته.',
        ),
    ];
  }

  Future<SmartDeviceLinkOffer> integrate({
    required ConnectionDevice device,
    required DeviceTransport transport,
    required bool peerConsent,
    List<int> inbound = const [],
  }) async {
    final privacy = requiresPrivacy(device);
    if (privacy && !peerConsent) {
      return SmartDeviceLinkOffer(
        device: device,
        requiresPrivacy: true,
        peerConsent: false,
        outboundAccepted: false,
        inboundSeen: false,
        noteAr: 'هذا الجهاز بخصوصية. لا إرسال ولا استقبال حتى يوافق.',
      );
    }
    if (!transport.hardwareBound) {
      device.state = ConnectionState.unbound;
      return SmartDeviceLinkOffer(
        device: device,
        requiresPrivacy: privacy,
        peerConsent: peerConsent,
        outboundAccepted: false,
        inboundSeen: false,
        noteAr: 'القناة غير مربوطة. لا تكامل بالاتجاهين.',
      );
    }
    final sent = await transport.send(device, const [1]);
    final inboundSeen = inbound.isNotEmpty;
    if (device.state == ConnectionState.disconnected) {
      device.state = ConnectionState.discovering;
    }
    final noteAr = !sent.accepted
        ? 'القناة رفضت الإرسال. الجهاز ليس متصلاً.'
        : inboundSeen
            ? 'تبادلت القناة بايتات بعد الموافقة. هذا ليس تحكماً بالجهاز.'
            : 'خرجت بايتات. لم يصل رد من الجهاز الآخر.';
    return SmartDeviceLinkOffer(
      device: device,
      requiresPrivacy: privacy,
      peerConsent: peerConsent,
      outboundAccepted: sent.accepted,
      inboundSeen: inboundSeen,
      noteAr: noteAr,
    );
  }
}
