/// =============================================================
/// Lifex-AI — اتصال محلي
/// الملف: lan_transport.dart
/// نقل Wi-Fi/LAN حقيقي بين تطبيقَي Lifex خلف واجهة DeviceTransport.
/// الظهور في دفتر الاقتران ليس اتصالاً؛ الاتصال يُعلَن بعد مصافحة بمفتاح الاقتران.
/// =============================================================
library lifex_ai.core.connectivity.lan.lan_transport;

import 'dart:async';
import 'dart:io';

import '../connection_device.dart';
import '../connection_security.dart';
import '../connection_state.dart';
import '../connection_type.dart';
import '../device_capability.dart';
import '../transport.dart';
import '../transport_streams.dart';
import 'lan_secure_channel.dart';

/// جهاز مقترن: عنوانه ومفتاحه. المفتاح يُتبادل خارج الشبكة ولا يُرسل عليها.
class LanEndpoint {
  LanEndpoint({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
    required List<int> pairingKey,
    this.capabilities = const [
      DeviceCapability.display,
      DeviceCapability.readData,
      DeviceCapability.writeData,
      DeviceCapability.streamData,
    ],
  }) : pairingKey = List<int>.unmodifiable(pairingKey) {
    if (pairingKey.length != 32) {
      throw ArgumentError('LAN pairing key must be 32 bytes');
    }
  }

  final String deviceId;
  final String name;
  final String host;
  final int port;
  final List<int> pairingKey;
  final List<DeviceCapability> capabilities;
}

class LanPairingBook {
  final _endpoints = <String, LanEndpoint>{};

  void pair(LanEndpoint endpoint) => _endpoints[endpoint.deviceId] = endpoint;
  void unpair(String deviceId) => _endpoints.remove(deviceId);
  LanEndpoint? operator [](String deviceId) => _endpoints[deviceId];
  bool isPaired(String deviceId) => _endpoints.containsKey(deviceId);
  List<LanEndpoint> get endpoints => List.unmodifiable(_endpoints.values);
}

typedef LanInbound = TransportInbound;
typedef LanStateChange = TransportStateChange;

typedef LanSocketConnector = Future<Socket> Function(String host, int port);

class LanTransport implements DeviceScopedTransport, SelfAuthenticatingTransport {
  LanTransport({
    required this.pairing,
    LanSocketConnector? connector,
    this.connectTimeout = const Duration(seconds: 5),
    this.handshakeTimeout = const Duration(seconds: 8),
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
  }) : _connector = connector ??
            ((host, port) => Socket.connect(host, port, timeout: connectTimeout));

  final LanPairingBook pairing;
  final LanSocketConnector _connector;
  final Duration connectTimeout;
  final Duration handshakeTimeout;
  final Duration baseBackoff;
  final Duration maxBackoff;

  final _channels = <String, LanSecureChannel>{};
  final _devices = <String, ConnectionDevice>{};
  final _wanted = <String>{};
  final _retryTimers = <String, Timer>{};
  final _attempts = <String, int>{};
  final _inbound = StreamController<LanInbound>.broadcast();
  final _states = StreamController<LanStateChange>.broadcast();

  @override
  ConnectionType get type => ConnectionType.wifi;

  @override
  bool get hardwareBound => true;

  @override
  Stream<List<int>> get incomingBytes => _inbound.stream.map((m) => m.bytes);

  /// الرسائل مع معرّف الجهاز المرسل.
  @override
  Stream<LanInbound> get inbound => _inbound.stream;
  @override
  Stream<LanStateChange> get stateChanges => _states.stream;

  @override
  bool get preservesMessageBoundaries => true;

  @override
  bool authenticatedSession(String deviceId) =>
      _channels[deviceId]?.isOpen ?? false;

  @override
  bool secureSession(String deviceId) => authenticatedSession(deviceId);

  /// الأجهزة المقترنة فقط. ليس اكتشافاً شبكياً (mDNS يحتاج حزمة).
  @override
  Future<List<ConnectionDevice>> scan() async => [
        for (final endpoint in pairing.endpoints)
          _devices[endpoint.deviceId] ??
              ConnectionDevice(
                id: endpoint.deviceId,
                name: endpoint.name,
                connectionType: ConnectionType.wifi,
                state: ConnectionState.disconnected,
                capabilities: endpoint.capabilities,
              ),
      ];

  void _setState(ConnectionDevice device, ConnectionState state) {
    device.state = state;
    if (!_states.isClosed) {
      _states.add(LanStateChange(deviceId: device.id, state: state));
    }
  }

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    final endpoint = pairing[device.id];
    if (endpoint == null) {
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    _devices[device.id] = device;
    _wanted.add(device.id);
    _retryTimers.remove(device.id)?.cancel();
    final opened = await _open(device, endpoint);
    if (!opened) {
      _wanted.remove(device.id);
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    return ConnectionState.connected;
  }

  Future<bool> _open(ConnectionDevice device, LanEndpoint endpoint) async {
    _setState(device, ConnectionState.connecting);
    try {
      final socket = await _connector(endpoint.host, endpoint.port)
          .timeout(connectTimeout);
      _setState(device, ConnectionState.authenticating);
      final channel = await LanSecureChannel.client(
        socket,
        LanFrameCipher(endpoint.pairingKey),
        timeout: handshakeTimeout,
      );
      if (!_wanted.contains(device.id)) {
        await channel.close();
        return false;
      }
      _channels[device.id] = channel;
      _attempts[device.id] = 0;
      channel.payloads.listen(
        (bytes) => _inbound.add(LanInbound(deviceId: device.id, bytes: bytes)),
      );
      unawaited(channel.done.then((_) => _dropped(device, channel)));
      _setState(device, ConnectionState.connected);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _dropped(ConnectionDevice device, LanSecureChannel channel) {
    if (!identical(_channels[device.id], channel)) return;
    _channels.remove(device.id);
    if (!_wanted.contains(device.id)) {
      _setState(device, ConnectionState.disconnected);
      return;
    }
    _scheduleRetry(device);
  }

  /// إعادة اتصال بمهلة تتضاعف حتى [maxBackoff]، دون تجميد الواجهة.
  void _scheduleRetry(ConnectionDevice device) {
    _setState(device, ConnectionState.reconnecting);
    final attempt = _attempts[device.id] ?? 0;
    _attempts[device.id] = attempt + 1;
    final wait =
        ReconnectBackoff(base: baseBackoff, max: maxBackoff).delayFor(attempt);
    _retryTimers[device.id]?.cancel();
    _retryTimers[device.id] = Timer(wait, () async {
      _retryTimers.remove(device.id);
      final endpoint = pairing[device.id];
      if (!_wanted.contains(device.id) || endpoint == null) return;
      final ok = await _open(device, endpoint);
      if (!ok && _wanted.contains(device.id)) _scheduleRetry(device);
    });
  }

  @override
  Future<void> disconnect(ConnectionDevice device) async {
    _wanted.remove(device.id);
    _retryTimers.remove(device.id)?.cancel();
    await _channels.remove(device.id)?.close();
    _setState(device, ConnectionState.disconnected);
  }

  @override
  Future<TransportSendResult> send(
    ConnectionDevice device,
    List<int> data,
  ) async {
    final channel = _channels[device.id];
    if (channel == null || !channel.isOpen) {
      return const TransportSendResult(accepted: false, reason: 'not_connected');
    }
    final sent = await channel.send(data);
    return TransportSendResult(
      accepted: sent,
      reason: sent ? '' : 'channel_closed',
    );
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

/// المضيف على الشاشة الثانية: يقبل عملاء Lifex بنفس مفتاح الاقتران فقط.
class LanSyncHost {
  LanSyncHost({required List<int> pairingKey}) : _cipher = LanFrameCipher(pairingKey);

  final LanFrameCipher _cipher;
  ServerSocket? _server;
  final _clients = <String, LanSecureChannel>{};
  final _inbound = StreamController<LanInbound>.broadcast();
  int _counter = 0;
  int rejectedHandshakes = 0;

  Stream<LanInbound> get inbound => _inbound.stream;
  int get connectedClients => _clients.length;
  int? get port => _server?.port;

  Future<int> start({Object? address, int port = 0}) async {
    final server = await ServerSocket.bind(address ?? InternetAddress.anyIPv4, port);
    _server = server;
    server.listen((socket) => unawaited(_accept(socket)));
    return server.port;
  }

  Future<void> _accept(Socket socket) async {
    try {
      final channel = await LanSecureChannel.host(socket, _cipher);
      final id = 'client-${++_counter}';
      _clients[id] = channel;
      channel.payloads.listen(
        (bytes) => _inbound.add(LanInbound(deviceId: id, bytes: bytes)),
      );
      unawaited(channel.done.then((_) => _clients.remove(id)));
    } catch (_) {
      rejectedHandshakes++;
    }
  }

  Future<bool> send(String clientId, List<int> data) async =>
      await _clients[clientId]?.send(data) ?? false;

  Future<int> broadcast(List<int> data) async {
    var delivered = 0;
    for (final channel in _clients.values.toList()) {
      if (await channel.send(data)) delivered++;
    }
    return delivered;
  }

  Future<void> stop() async {
    for (final channel in _clients.values.toList()) {
      await channel.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
  }
}
