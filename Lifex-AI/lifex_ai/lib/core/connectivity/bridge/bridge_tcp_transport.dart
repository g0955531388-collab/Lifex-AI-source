/// =============================================================
/// Lifex-AI — جسر العتاد
/// الملف: bridge_tcp_transport.dart
/// اتصال TCP/TLS بأجهزة لا تُثبَّت عليها Lifex (جسر عتاد، GPS، روبوت، درون).
/// بلا TLS: القناة تُعلَن غير آمنة، ولا يُخفى ذلك عن السواقات أو الواجهة.
/// =============================================================
library lifex_ai.core.connectivity.bridge.bridge_tcp_transport;

import 'dart:async';
import 'dart:io';

import 'package:cryptography/dart.dart';

import '../connection_device.dart';
import '../connection_state.dart';
import '../connection_type.dart';
import '../device_capability.dart';
import '../transport.dart';
import '../transport_streams.dart';

class BridgeEndpoint {
  BridgeEndpoint({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
    this.tls = false,
    List<int>? pinnedCertificateSha256,
    this.capabilities = const [DeviceCapability.readData],
  }) : pinnedCertificateSha256 = pinnedCertificateSha256 == null
            ? null
            : List<int>.unmodifiable(pinnedCertificateSha256) {
    if (pinnedCertificateSha256 != null) {
      if (!tls) throw ArgumentError('certificate pin requires tls');
      if (pinnedCertificateSha256.length != 32) {
        throw ArgumentError('certificate pin must be a SHA-256 digest');
      }
    }
  }

  final String deviceId;
  final String name;
  final String host;
  final int port;
  final bool tls;

  /// بصمة SHA-256 لشهادة الجهاز (DER). تسمح بشهادة ذاتية التوقيع معروفة مسبقاً فقط.
  final List<int>? pinnedCertificateSha256;
  final List<DeviceCapability> capabilities;
}

class BridgeEndpointBook {
  final _endpoints = <String, BridgeEndpoint>{};

  void add(BridgeEndpoint endpoint) => _endpoints[endpoint.deviceId] = endpoint;
  void remove(String deviceId) => _endpoints.remove(deviceId);
  BridgeEndpoint? operator [](String deviceId) => _endpoints[deviceId];
  List<BridgeEndpoint> get endpoints => List.unmodifiable(_endpoints.values);
}

typedef BridgeSocketConnector = Future<Socket> Function(
  BridgeEndpoint endpoint,
  Duration timeout,
);

bool certificateMatchesPin(X509Certificate? certificate, List<int> pin) {
  if (certificate == null) return false;
  final digest = const DartSha256().hashSync(certificate.der).bytes;
  if (digest.length != pin.length) return false;
  var diff = 0;
  for (var i = 0; i < pin.length; i++) {
    diff |= digest[i] ^ pin[i];
  }
  return diff == 0;
}

Future<Socket> _defaultConnector(BridgeEndpoint endpoint, Duration timeout) async {
  if (!endpoint.tls) {
    return Socket.connect(endpoint.host, endpoint.port, timeout: timeout);
  }
  final pin = endpoint.pinnedCertificateSha256;
  final socket = await SecureSocket.connect(
    endpoint.host,
    endpoint.port,
    timeout: timeout,
    onBadCertificate: pin == null ? null : (cert) => certificateMatchesPin(cert, pin),
  );
  if (pin != null && !certificateMatchesPin(socket.peerCertificate, pin)) {
    socket.destroy();
    throw const HandshakeException('certificate_pin_mismatch');
  }
  return socket;
}

class BridgeTcpTransport implements DeviceScopedTransport {
  BridgeTcpTransport({
    required this.endpoints,
    BridgeSocketConnector? connector,
    this.connectTimeout = const Duration(seconds: 5),
    this.backoff = const ReconnectBackoff(),
  }) : _connector = connector ?? _defaultConnector;

  final BridgeEndpointBook endpoints;
  final BridgeSocketConnector _connector;
  final Duration connectTimeout;
  final ReconnectBackoff backoff;

  final _sockets = <String, Socket>{};
  final _secure = <String>{};
  final _devices = <String, ConnectionDevice>{};
  final _wanted = <String>{};
  final _retryTimers = <String, Timer>{};
  final _attempts = <String, int>{};
  final _inbound = StreamController<TransportInbound>.broadcast();
  final _states = StreamController<TransportStateChange>.broadcast();

  @override
  ConnectionType get type => ConnectionType.network;

  @override
  bool get hardwareBound => true;

  @override
  bool get preservesMessageBoundaries => false;

  @override
  Stream<List<int>> get incomingBytes => _inbound.stream.map((m) => m.bytes);

  @override
  Stream<TransportInbound> get inbound => _inbound.stream;

  @override
  Stream<TransportStateChange> get stateChanges => _states.stream;

  @override
  bool secureSession(String deviceId) =>
      _sockets.containsKey(deviceId) && _secure.contains(deviceId);

  /// الأجهزة المسجّلة فقط. الاكتشاف الشبكي (mDNS) يحتاج حزمة.
  @override
  Future<List<ConnectionDevice>> scan() async => [
        for (final e in endpoints.endpoints)
          _devices[e.deviceId] ??
              ConnectionDevice(
                id: e.deviceId,
                name: e.name,
                connectionType: ConnectionType.network,
                state: ConnectionState.disconnected,
                capabilities: e.capabilities,
              ),
      ];

  void _setState(ConnectionDevice device, ConnectionState state) {
    device.state = state;
    if (!_states.isClosed) {
      _states.add(TransportStateChange(deviceId: device.id, state: state));
    }
  }

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    final endpoint = endpoints[device.id];
    if (endpoint == null) {
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    _devices[device.id] = device;
    _wanted.add(device.id);
    _retryTimers.remove(device.id)?.cancel();
    if (!await _open(device, endpoint)) {
      _wanted.remove(device.id);
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    return ConnectionState.connected;
  }

  Future<bool> _open(ConnectionDevice device, BridgeEndpoint endpoint) async {
    _setState(device, ConnectionState.connecting);
    try {
      final socket =
          await _connector(endpoint, connectTimeout).timeout(connectTimeout);
      if (!_wanted.contains(device.id)) {
        socket.destroy();
        return false;
      }
      _sockets[device.id] = socket;
      if (endpoint.tls) {
        _secure.add(device.id);
      } else {
        _secure.remove(device.id);
      }
      _attempts[device.id] = 0;
      socket.listen(
        (bytes) {
          if (!_inbound.isClosed) {
            _inbound.add(TransportInbound(deviceId: device.id, bytes: bytes));
          }
        },
        onError: (Object _) => _dropped(device, socket),
        onDone: () => _dropped(device, socket),
        cancelOnError: true,
      );
      _setState(device, ConnectionState.connected);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _dropped(ConnectionDevice device, Socket socket) {
    if (!identical(_sockets[device.id], socket)) return;
    _sockets.remove(device.id);
    _secure.remove(device.id);
    socket.destroy();
    if (!_wanted.contains(device.id)) {
      _setState(device, ConnectionState.disconnected);
      return;
    }
    _scheduleRetry(device);
  }

  void _scheduleRetry(ConnectionDevice device) {
    _setState(device, ConnectionState.reconnecting);
    final attempt = _attempts[device.id] ?? 0;
    _attempts[device.id] = attempt + 1;
    _retryTimers[device.id]?.cancel();
    _retryTimers[device.id] = Timer(backoff.delayFor(attempt), () async {
      _retryTimers.remove(device.id);
      final endpoint = endpoints[device.id];
      if (!_wanted.contains(device.id) || endpoint == null) return;
      final ok = await _open(device, endpoint);
      if (!ok && _wanted.contains(device.id)) _scheduleRetry(device);
    });
  }

  @override
  Future<void> disconnect(ConnectionDevice device) async {
    _wanted.remove(device.id);
    _retryTimers.remove(device.id)?.cancel();
    _secure.remove(device.id);
    _sockets.remove(device.id)?.destroy();
    _setState(device, ConnectionState.disconnected);
  }

  @override
  Future<TransportSendResult> send(
    ConnectionDevice device,
    List<int> data,
  ) async {
    final socket = _sockets[device.id];
    if (socket == null) {
      return const TransportSendResult(accepted: false, reason: 'not_connected');
    }
    try {
      socket.add(data);
      await socket.flush();
      return const TransportSendResult(accepted: true);
    } catch (_) {
      return const TransportSendResult(accepted: false, reason: 'socket_closed');
    }
  }

  Future<void> dispose() async {
    for (final id in _wanted.toList()) {
      final device = _devices[id];
      if (device != null) await disconnect(device);
    }
    await _inbound.close();
    await _states.close();
  }
}
