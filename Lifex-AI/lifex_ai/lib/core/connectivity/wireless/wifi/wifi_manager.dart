/// =============================================================
/// Lifex-AI — اتصال لاسلكي
/// الملف: wifi_manager.dart
/// مضيف المستشفى غير مربوط ليس خادماً حياً.
/// =============================================================
library lifex_ai.core.connectivity.wireless.wifi_manager;

import '../../connection_state.dart';
import '../../transport.dart';

abstract class WifiConnection {
  Future<ConnectionState> connect(String host, int port);
  Future<void> disconnect();
  Future<TransportSendResult> send(List<int> data);
  Stream<List<int>> get incomingData;
}

class UnboundWifiConnection implements WifiConnection {
  bool _open = false;

  @override
  Stream<List<int>> get incomingData => const Stream.empty();

  @override
  Future<ConnectionState> connect(String host, int port) async {
    _open = false;
    return ConnectionState.unbound;
  }

  @override
  Future<void> disconnect() async {
    _open = false;
  }

  @override
  Future<TransportSendResult> send(List<int> data) async {
    return const TransportSendResult(
      accepted: false,
      reason: 'wifi_unbound',
    );
  }

  bool get isConnected => _open;
}

class WifiDevice {
  const WifiDevice({required this.host, required this.port});
  final String host;
  final int port;
}

class WifiManager {
  WifiManager({WifiConnection? connection})
      : connection = connection ?? UnboundWifiConnection();

  final WifiConnection connection;
}

class WifiDirectManager {
  const WifiDirectManager();

  bool get osSupportedUnknown => true;

  Future<ConnectionState> connectPeer(String peerId) async {
    return ConnectionState.unbound;
  }
}

