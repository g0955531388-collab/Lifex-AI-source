/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: device_link_state.dart
/// حالة كل جهاز كلقطات ثابتة على Stream للواجهة ومحرك الذكاء.
/// متصل ≠ آمن ≠ مخوَّل ≠ قابل للتحكم؛ كل منها حقل مستقل.
/// =============================================================
library lifex_ai.core.device_integration.state.device_link_state;

import 'dart:async';

import '../../connectivity/connection_state.dart';
import '../../device_control_center/control_types.dart';

class CommandTrace {
  const CommandTrace({
    required this.commandId,
    required this.action,
    required this.status,
    required this.at,
    this.reason = '',
  });

  final String commandId;
  final String action;
  final CommandStatus status;
  final DateTime at;
  final String reason;
}

class DeviceLinkSnapshot {
  const DeviceLinkSnapshot({
    required this.deviceId,
    this.connection = ConnectionState.disconnected,
    this.secureChannel = false,
    this.readAuthorized = false,
    this.controlAuthorized = false,
    this.lastSeen,
    this.values = const {},
    this.declaredActions,
    this.lastCommand,
  });

  final String deviceId;
  final ConnectionState connection;
  final bool secureChannel;
  final bool readAuthorized;
  final bool controlAuthorized;
  final DateTime? lastSeen;
  final Map<String, Object?> values;

  /// الأوامر التي أعلنها الجهاز بنفسه. null = لم يعلن.
  final Set<String>? declaredActions;
  final CommandTrace? lastCommand;

  bool get connected => connection == ConnectionState.connected;

  bool get controllable => connected && secureChannel && controlAuthorized;

  DeviceLinkSnapshot copyWith({
    ConnectionState? connection,
    bool? secureChannel,
    bool? readAuthorized,
    bool? controlAuthorized,
    DateTime? lastSeen,
    Map<String, Object?>? values,
    Set<String>? declaredActions,
    CommandTrace? lastCommand,
  }) =>
      DeviceLinkSnapshot(
        deviceId: deviceId,
        connection: connection ?? this.connection,
        secureChannel: secureChannel ?? this.secureChannel,
        readAuthorized: readAuthorized ?? this.readAuthorized,
        controlAuthorized: controlAuthorized ?? this.controlAuthorized,
        lastSeen: lastSeen ?? this.lastSeen,
        values: values ?? this.values,
        declaredActions: declaredActions ?? this.declaredActions,
        lastCommand: lastCommand ?? this.lastCommand,
      );
}

class DeviceLinkStateStore {
  final _snapshots = <String, DeviceLinkSnapshot>{};
  final _changes = StreamController<DeviceLinkSnapshot>.broadcast();

  DeviceLinkSnapshot of(String deviceId) =>
      _snapshots[deviceId] ?? DeviceLinkSnapshot(deviceId: deviceId);

  Stream<DeviceLinkSnapshot> get changes => _changes.stream;

  /// اللقطة الحالية ثم كل تغيير لاحق.
  Stream<DeviceLinkSnapshot> watch(String deviceId) {
    late StreamController<DeviceLinkSnapshot> out;
    StreamSubscription<DeviceLinkSnapshot>? sub;
    out = StreamController<DeviceLinkSnapshot>(
      onListen: () {
        out.add(of(deviceId));
        sub = _changes.stream
            .where((s) => s.deviceId == deviceId)
            .listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  DeviceLinkSnapshot update(
    String deviceId,
    DeviceLinkSnapshot Function(DeviceLinkSnapshot current) change,
  ) {
    final next = change(of(deviceId));
    _snapshots[deviceId] = next;
    if (!_changes.isClosed) _changes.add(next);
    return next;
  }

  Future<void> close() => _changes.close();
}
