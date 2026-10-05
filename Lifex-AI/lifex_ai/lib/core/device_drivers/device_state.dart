/// =============================================================
/// Lifex-AI — سواقات
/// الملف: device_state.dart
/// =============================================================
library lifex_ai.core.device_drivers.device_state;

class DeviceState {
  const DeviceState({
    required this.deviceId,
    required this.connected,
    required this.powered,
    this.values = const {},
  });

  final String deviceId;
  final bool connected;
  final bool powered;
  final Map<String, dynamic> values;

  factory DeviceState.empty() => const DeviceState(
        deviceId: '',
        connected: false,
        powered: false,
      );

  DeviceState copyWith({
    bool? connected,
    bool? powered,
    Map<String, dynamic>? values,
  }) {
    return DeviceState(
      deviceId: deviceId,
      connected: connected ?? this.connected,
      powered: powered ?? this.powered,
      values: values ?? this.values,
    );
  }
}
