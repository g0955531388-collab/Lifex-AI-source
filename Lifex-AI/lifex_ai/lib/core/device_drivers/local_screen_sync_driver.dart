/// =============================================================
/// Lifex-AI — سواقات
/// الملف: local_screen_sync_driver.dart
/// مزامنة بين تطبيقَي Lifex على الشبكة المحلية (هاتف ↔ شاشة).
/// الأمر لا يُعدّ منفّذاً إلا بتأكيد من الطرف الآخر. البيانات الصحية لا تُرسل
/// إلى شاشة أخرى بلا مرجع موافقة.
/// =============================================================
library lifex_ai.core.device_drivers.local_screen_sync_driver;

import 'dart:async';

import '../connectivity/connection_device.dart';
import '../connectivity/connection_type.dart';
import '../connectivity/lan/lan_transport.dart';
import '../device_integration/drivers/screen_display_driver.dart';
import '../device_integration/protocols/lifex_bridge_protocol.dart';

/// الاقتران بمفتاح Lifex هو منح العرض؛ والطرف الآخر يقرر الأوامر التي يقبلها.
class LocalScreenSyncDriver extends ScreenDisplayDriver {
  LocalScreenSyncDriver({
    required LanTransport transport,
    super.pipeline,
    super.states,
    super.ackTimeout,
  })  : lan = transport,
        super(
          transport: transport,
          explicitGrant: false,
          peerDeclaresActions: false,
        );

  final LanTransport lan;

  @override
  String get driverId => 'lifex.lan.screen_sync';

  @override
  String get name => 'Lifex screen sync (LAN)';

  @override
  Future<bool> detect(ConnectionDevice device) async =>
      device.connectionType == ConnectionType.wifi &&
      lan.pairing.isPaired(device.id);
}

/// على الشاشة الثانية: ينفّذ الأوامر عبر [handler] ويرد بتأكيد صادق.
class LocalScreenSyncResponder {
  LocalScreenSyncResponder({
    required this.host,
    required this.handler,
  }) {
    _subscription = host.inbound.listen((inbound) => unawaited(_onInbound(inbound)));
  }

  final LanSyncHost host;

  /// يعيد null عند النجاح، أو سبب الرفض.
  final Future<String?> Function(String action, Map<String, dynamic> params) handler;
  late final StreamSubscription<LanInbound> _subscription;

  Future<void> _onInbound(LanInbound inbound) async {
    final message = LbpMessage.decode(inbound.bytes);
    if (message == null || message['t'] != 'cmd') return;
    final params = message['params'];
    final map = params is Map<String, dynamic> ? params : <String, dynamic>{};
    var refusal = LbpMessage.healthDataRefusal(map);
    if (refusal == null) {
      try {
        refusal = await handler(message['action']?.toString() ?? '', map);
      } catch (_) {
        refusal = 'handler_failed';
      }
    }
    await host.send(
      inbound.deviceId,
      LbpMessage.encode({
        't': 'ack',
        'id': message['id'],
        'ok': refusal == null,
        if (refusal != null) 'reason': refusal,
      }),
    );
  }

  Future<void> publishCapabilities(Iterable<String> actions) =>
      host.broadcast(LbpMessage.encode({'t': 'caps', 'actions': actions.toList()}));

  Future<void> publishState(Map<String, Object?> values) =>
      host.broadcast(LbpMessage.encode({'t': 'state', 'values': values}));

  Future<void> publishEvent(String kind, Map<String, Object?> payload) =>
      host.broadcast(
        LbpMessage.encode({'t': 'event', 'kind': kind, 'payload': payload}),
      );

  Future<void> publishReading(String channel, Object value, {String unit = ''}) =>
      host.broadcast(LbpMessage.encode({
        't': 'reading',
        'channel': channel,
        'value': value,
        if (unit.isNotEmpty) 'unit': unit,
      }));

  Future<void> dispose() => _subscription.cancel();
}
