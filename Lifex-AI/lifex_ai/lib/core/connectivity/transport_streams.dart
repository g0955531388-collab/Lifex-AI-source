/// =============================================================
/// Lifex-AI — اتصال
/// الملف: transport_streams.dart
/// نقل يعرف مصدر كل رسالة وحالة كل جهاز، وهل قناته آمنة الآن.
/// =============================================================
library lifex_ai.core.connectivity.transport_streams;

import 'dart:math';

import 'connection_state.dart';
import 'transport.dart';

class TransportInbound {
  const TransportInbound({required this.deviceId, required this.bytes});
  final String deviceId;
  final List<int> bytes;
}

class TransportStateChange {
  const TransportStateChange({required this.deviceId, required this.state});
  final String deviceId;
  final ConnectionState state;
}

abstract class DeviceScopedTransport implements DeviceTransport {
  Stream<TransportInbound> get inbound;
  Stream<TransportStateChange> get stateChanges;

  /// القناة مشفّرة والطرف الآخر مُثبت الهوية لهذا الجهاز الآن.
  bool secureSession(String deviceId);

  /// true: كل وارد رسالة كاملة. false: بايتات متدفقة تحتاج تأطيراً.
  bool get preservesMessageBoundaries;
}

/// مهلة إعادة الاتصال تتضاعف حتى سقف، دون تجميد الواجهة.
class ReconnectBackoff {
  const ReconnectBackoff({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
  });

  final Duration base;
  final Duration max;

  Duration delayFor(int attempt) => Duration(
        milliseconds: min(
          base.inMilliseconds * (1 << min(attempt, 16)),
          max.inMilliseconds,
        ),
      );
}
