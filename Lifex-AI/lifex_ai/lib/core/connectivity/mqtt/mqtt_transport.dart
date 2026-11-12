/// =============================================================
/// Lifex-AI — اتصال MQTT
/// الملف: mqtt_transport.dart
/// أجهزة منزلية وطبية وحساسات عبر وسيط MQTT (3.1.1).
/// لكل جهاز موضوعان: وارد منه، وأوامر إليه. "متصل" بعد تأكيد الوسيط للاشتراك.
/// "آمن" = TLS إلى الوسيط؛ الوسيط نفسه طرف موثوق في هذا المسار.
/// =============================================================
library lifex_ai.core.connectivity.mqtt.mqtt_transport;

import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../bridge/bridge_tcp_transport.dart' show certificateMatchesPin;
import '../connection_device.dart';
import '../connection_state.dart';
import '../connection_type.dart';
import '../device_capability.dart';
import '../transport.dart';
import '../transport_streams.dart';

class MqttBrokerConfig {
  MqttBrokerConfig({
    required this.host,
    required this.clientId,
    this.tls = true,
    int? port,
    List<int>? trustedSelfSignedSha256,
    this.username,
    this.password,
    this.keepAliveSeconds = 20,
    this.connectTimeout = const Duration(seconds: 5),
  })  : port = port ?? (tls ? 8883 : 1883),
        trustedSelfSignedSha256 = trustedSelfSignedSha256 == null
            ? null
            : List<int>.unmodifiable(trustedSelfSignedSha256) {
    if (trustedSelfSignedSha256 != null &&
        (!tls || trustedSelfSignedSha256.length != 32)) {
      throw ArgumentError('trusted certificate needs tls and a SHA-256 digest');
    }
  }

  final String host;
  final int port;
  final String clientId;
  final bool tls;

  /// بصمة شهادة وسيط ذاتية التوقيع معروفة مسبقاً. الشهادات الموقّعة من جهة
  /// معتمدة تُقبل عبر ثقة النظام.
  final List<int>? trustedSelfSignedSha256;
  final String? username;
  final String? password;
  final int keepAliveSeconds;
  final Duration connectTimeout;
}

class MqttDeviceTopics {
  MqttDeviceTopics({
    required this.deviceId,
    required this.name,
    required this.inboundTopic,
    required this.commandTopic,
    this.capabilities = const [DeviceCapability.readData],
  }) {
    for (final t in [inboundTopic, commandTopic]) {
      if (t.isEmpty || t.contains('+') || t.contains('#')) {
        throw ArgumentError('device topics must be exact (no wildcards): $t');
      }
    }
  }

  final String deviceId;
  final String name;

  /// الجهاز ← Lifex.
  final String inboundTopic;

  /// Lifex ← الجهاز.
  final String commandTopic;
  final List<DeviceCapability> capabilities;
}

class MqttTopicBook {
  final _devices = <String, MqttDeviceTopics>{};

  void add(MqttDeviceTopics topics) => _devices[topics.deviceId] = topics;
  void remove(String deviceId) => _devices.remove(deviceId);
  MqttDeviceTopics? operator [](String deviceId) => _devices[deviceId];
  List<MqttDeviceTopics> get all => List.unmodifiable(_devices.values);
}

typedef MqttClientFactory = MqttServerClient Function(MqttBrokerConfig config);

class MqttTransport implements DeviceScopedTransport {
  MqttTransport({
    required this.broker,
    required this.topics,
    MqttClientFactory? clientFactory,
    this.subscribeTimeout = const Duration(seconds: 5),
  }) : _factory = clientFactory ?? _defaultClient;

  final MqttBrokerConfig broker;
  final MqttTopicBook topics;
  final Duration subscribeTimeout;
  final MqttClientFactory _factory;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  final _devices = <String, ConnectionDevice>{};
  final _wanted = <String>{};
  final _subscribed = <String>{};
  final _subAcks = <String, Completer<bool>>{};
  final _inbound = StreamController<TransportInbound>.broadcast();
  final _states = StreamController<TransportStateChange>.broadcast();

  static MqttServerClient _defaultClient(MqttBrokerConfig config) =>
      MqttServerClient.withPort(config.host, config.clientId, config.port);

  @override
  ConnectionType get type => ConnectionType.network;

  @override
  bool get hardwareBound => true;

  @override
  bool get preservesMessageBoundaries => true;

  @override
  Stream<List<int>> get incomingBytes => _inbound.stream.map((m) => m.bytes);

  @override
  Stream<TransportInbound> get inbound => _inbound.stream;

  @override
  Stream<TransportStateChange> get stateChanges => _states.stream;

  bool get _brokerUp =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  bool secureSession(String deviceId) =>
      broker.tls && _brokerUp && _subscribed.contains(deviceId);

  @override
  Future<List<ConnectionDevice>> scan() async => [
        for (final t in topics.all)
          _devices[t.deviceId] ??
              ConnectionDevice(
                id: t.deviceId,
                name: t.name,
                connectionType: ConnectionType.network,
                state: ConnectionState.disconnected,
                capabilities: t.capabilities,
              ),
      ];

  void _setState(ConnectionDevice device, ConnectionState state) {
    device.state = state;
    if (!_states.isClosed) {
      _states.add(TransportStateChange(deviceId: device.id, state: state));
    }
  }

  void _setAll(ConnectionState state) {
    for (final id in _wanted) {
      final d = _devices[id];
      if (d != null) _setState(d, state);
    }
  }

  Future<bool> _ensureBroker() async {
    if (_brokerUp) return true;
    final client = _factory(broker)
      ..setProtocolV311()
      ..logging(on: false)
      ..keepAlivePeriod = broker.keepAliveSeconds
      ..connectTimeoutPeriod = broker.connectTimeout.inMilliseconds
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..secure = broker.tls;
    final trusted = broker.trustedSelfSignedSha256;
    if (trusted != null) {
      // mqtt_client 10.3 يحوّل الدالة داخلياً إلى bool Function(Object).
      client.onBadCertificate = (Object cert) =>
          cert is X509Certificate && certificateMatchesPin(cert, trusted);
    }
    client.onSubscribed = (topic) {
      _subAcks.remove(topic)?.complete(true);
    };
    client.onSubscribeFail = (topic) {
      _subAcks.remove(topic)?.complete(false);
    };
    client.onAutoReconnect = () {
      _setAll(ConnectionState.reconnecting);
    };
    client.onAutoReconnected = () {
      for (final id in _wanted) {
        final d = _devices[id];
        if (d != null && _subscribed.contains(id)) {
          _setState(d, ConnectionState.connected);
        }
      }
    };
    try {
      final status = await client.connect(broker.username, broker.password);
      if (status?.state != MqttConnectionState.connected) {
        client.disconnect();
        return false;
      }
    } catch (_) {
      client.disconnect();
      return false;
    }
    _client = client;
    await _updates?.cancel();
    _updates = client.updates?.listen(_onUpdates);
    return true;
  }

  void _onUpdates(List<MqttReceivedMessage<MqttMessage>> batch) {
    for (final m in batch) {
      final message = m.payload;
      if (message is! MqttPublishMessage) continue;
      for (final t in topics.all) {
        if (t.inboundTopic == m.topic && _subscribed.contains(t.deviceId)) {
          _inbound.add(TransportInbound(
            deviceId: t.deviceId,
            bytes: List<int>.of(message.payload.message),
          ));
        }
      }
    }
  }

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    final t = topics[device.id];
    if (t == null) {
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    _devices[device.id] = device;
    _wanted.add(device.id);
    _setState(device, ConnectionState.connecting);
    if (!await _ensureBroker()) {
      _wanted.remove(device.id);
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    final ack = Completer<bool>();
    _subAcks[t.inboundTopic] = ack;
    _client!.subscribe(t.inboundTopic, MqttQos.atLeastOnce);
    final ok = await ack.future.timeout(subscribeTimeout, onTimeout: () => false);
    if (!ok || !_wanted.contains(device.id)) {
      _subAcks.remove(t.inboundTopic);
      _wanted.remove(device.id);
      _setState(device, ConnectionState.error);
      return ConnectionState.error;
    }
    _subscribed.add(device.id);
    _setState(device, ConnectionState.connected);
    return ConnectionState.connected;
  }

  @override
  Future<void> disconnect(ConnectionDevice device) async {
    _wanted.remove(device.id);
    final t = topics[device.id];
    if (_subscribed.remove(device.id) && t != null && _brokerUp) {
      _client!.unsubscribe(t.inboundTopic);
    }
    _setState(device, ConnectionState.disconnected);
    if (_wanted.isEmpty) {
      await _updates?.cancel();
      _updates = null;
      _client?.autoReconnect = false;
      _client?.disconnect();
      _client = null;
    }
  }

  @override
  Future<TransportSendResult> send(
    ConnectionDevice device,
    List<int> data,
  ) async {
    final t = topics[device.id];
    if (t == null || !_subscribed.contains(device.id) || !_brokerUp) {
      return const TransportSendResult(accepted: false, reason: 'not_connected');
    }
    final builder = MqttClientPayloadBuilder();
    for (final b in data) {
      builder.addByte(b);
    }
    try {
      _client!.publishMessage(t.commandTopic, MqttQos.atLeastOnce, builder.payload!);
      return const TransportSendResult(accepted: true);
    } catch (_) {
      return const TransportSendResult(accepted: false, reason: 'publish_failed');
    }
  }

  Future<void> dispose() async {
    for (final id in _wanted.toList()) {
      final d = _devices[id];
      if (d != null) await disconnect(d);
    }
    await _inbound.close();
    await _states.close();
  }
}
