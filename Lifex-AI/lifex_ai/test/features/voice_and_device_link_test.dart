import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/core/connectivity/connection_device.dart';
import 'package:lifex_ai/core/connectivity/connection_state.dart';
import 'package:lifex_ai/core/connectivity/connection_type.dart';
import 'package:lifex_ai/core/connectivity/smart_device_link.dart';
import 'package:lifex_ai/core/connectivity/transport.dart';
import 'package:lifex_ai/features/voice/voice_engine.dart';

void main() {
  test('إيقاف الأوامر لا يفتح الميكروفون', () async {
    final engine = VoiceEngine.instance;
    final previous = AppConfig.instance.voiceCommandsEnabled;
    var listened = false;
    engine.bindListeningImplementation(() async {
      listened = true;
      return const VoiceOperationResult.success(textResult: 'أمر');
    });
    AppConfig.instance.voiceCommandsEnabled = false;
    final heard = await engine.startListening();
    expect(listened, isFalse);
    expect(heard.success, isFalse);
    expect(heard.errorMessageAr, contains('النطق'));
    AppConfig.instance.voiceCommandsEnabled = previous;
  });

  test('بحث القنوات غير المربوطة لا يخترع جهازاً', () async {
    final found = await SmartDeviceLink().search();
    expect(found, isEmpty);
  });

  test('جهاز بخصوصية لا يُرسل إليه قبل موافقته', () async {
    final device = ConnectionDevice(
      id: 'lamp-1',
      name: 'مصباح',
      connectionType: ConnectionType.bluetooth,
      state: ConnectionState.discovering,
      identityConfirmed: true,
    );
    final transport = _BoundTransport();
    final blocked = await SmartDeviceLink().integrate(
      device: device,
      transport: transport,
      peerConsent: false,
    );
    expect(transport.sent, isFalse);
    expect(blocked.exchanged, isFalse);
    expect(blocked.noteAr, contains('يوافق'));

    final open = await SmartDeviceLink().integrate(
      device: device,
      transport: transport,
      peerConsent: true,
      inbound: const [2],
    );
    expect(transport.sent, isTrue);
    expect(open.exchanged, isTrue);
    expect(open.noteAr, contains('ليس تحكماً'));
    expect(device.state, isNot(ConnectionState.connected));
  });
}

class _BoundTransport implements DeviceTransport {
  var sent = false;

  @override
  ConnectionType get type => ConnectionType.bluetooth;

  @override
  bool get hardwareBound => true;

  @override
  Stream<List<int>> get incomingBytes => const Stream.empty();

  @override
  Future<List<ConnectionDevice>> scan() async => const [];

  @override
  Future<ConnectionState> connect(ConnectionDevice device) async {
    return ConnectionState.connecting;
  }

  @override
  Future<void> disconnect(ConnectionDevice device) async {}

  @override
  Future<TransportSendResult> send(
    ConnectionDevice device,
    List<int> data,
  ) async {
    sent = true;
    return const TransportSendResult(accepted: true);
  }
}
