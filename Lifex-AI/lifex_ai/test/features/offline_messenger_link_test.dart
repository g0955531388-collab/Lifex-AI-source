import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/connectivity/connection_state.dart';
import 'package:lifex_ai/core/connectivity/transport.dart';
import 'package:lifex_ai/core/connectivity/wireless/wifi/wifi_manager.dart';
import 'package:lifex_ai/features/messaging/messenger_directory.dart';
import 'package:lifex_ai/features/messaging/offline_messenger_link.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  test('alias is not a lookup and email matches exactly', () {
    const directory = MessengerDirectory();
    final me = HealthProfile(
      profileId: 'me',
      fullName: 'الاسم القانوني',
      questionnaireData: {
        'accountPhone': '963900000111',
        'accountEmail': 'Me@Example.com',
      },
    );
    final peer = HealthProfile(
      profileId: 'peer',
      fullName: 'اسم مخفي',
      questionnaireData: {
        'accountPhone': '963900000222',
        'accountEmail': 'peer@example.com',
        'messengerAlias': 'نور',
      },
    );
    expect(directory.register(me: me, alias: 'ن', rawEmail: 'me@example.com'), 'aliasShort');
    expect(
      directory.register(me: me, alias: 'سالم', rawPhone: '', rawEmail: ''),
      'needPhoneOrEmail',
    );
    expect(directory.register(me: me, alias: 'سالم', rawEmail: 'me@example.com'), isNull);
    expect(MessengerDirectory.labelOf(me), 'سالم');
    expect(MessengerDirectory.labelOf(me).contains('القانوني'), isFalse);
    expect(
      directory.find(me: me, peers: [peer], rawPhone: 'نور'),
      isNull,
    );
    expect(
      directory.find(me: me, peers: [peer], rawEmail: 'Peer@Example.com')?.profileId,
      'peer',
    );
    expect(
      directory.find(me: me, peers: [peer], rawEmail: 'me@example.com'),
      isNull,
    );
    peer.questionnaireData['messengerPlace'] = 'حمص';
    peer.questionnaireData['accountLifexId'] = 'LX-22';
    final byName = directory.search(me: me, peers: [peer], query: 'مخفي');
    expect(byName.single.via, 'name');
    expect(MessengerDirectory.labelOf(byName.single.profile), 'نور');
    expect(
      directory.search(me: me, peers: [peer], query: 'LX-22').single.via,
      'id',
    );
    expect(
      directory.search(me: me, peers: [peer], query: 'حم').single.via,
      'place',
    );
    expect(directory.search(me: me, peers: [peer], query: 'ن'), isEmpty);
  });

  test('offline send opens sms and share and does not invent a cable peer', () async {
    final result = await const OfflineMessengerLink().send(
      phone: '963 900 000 222',
      message: 'سلام',
      openSmsDraft: ({required phone, required body}) async => true,
      openShareSheet: (_) async => true,
    );
    expect(result.serverDeliveryConfirmed, isFalse);
    expect(result.peerReceiptConfirmed, isFalse);
    expect(
      result.attempts.map((item) => item.phraseKey),
      containsAll([
        'smsDraftOpened',
        'shareSheetOpened',
        'bluetoothUnbound',
        'wifiUnbound',
        'cableUnbound',
      ]),
    );
    expect(result.attempts.every((item) => item.bytesAccepted == false), isTrue);
  });

  test('a local link that accepts bytes is still not a receipt', () async {
    final result = await OfflineMessengerLink(wifi: _AcceptWifi()).send(
      phone: '123',
      message: 'سلام',
      openSmsDraft: ({required phone, required body}) async => false,
      openShareSheet: (_) async => false,
    );
    final wifi = result.attempts.singleWhere(
      (item) => item.channel == OfflineChannel.wifi,
    );
    expect(wifi.bytesAccepted, isTrue);
    expect(wifi.phraseKey, 'linkAcceptedNoReceipt');
    expect(result.peerReceiptConfirmed, isFalse);
    expect(result.serverDeliveryConfirmed, isFalse);
    expect(
      result.attempts.singleWhere((item) => item.channel == OfflineChannel.sms).phraseKey,
      'phoneShort',
    );
  });

  test('an empty offline message does not open a draft', () async {
    var drafts = 0;
    final result = await const OfflineMessengerLink().send(
      phone: '963900000222',
      message: '   ',
      openSmsDraft: ({required phone, required body}) async {
        drafts++;
        return true;
      },
      openShareSheet: (_) async => true,
    );
    expect(drafts, 0);
    expect(result.attempts.single.phraseKey, 'empty');
    expect(result.anyHandoffOpened, isFalse);
  });
}

class _AcceptWifi implements WifiConnection {
  @override
  Future<ConnectionState> connect(String host, int port) async {
    return ConnectionState.connected;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Stream<List<int>> get incomingData => const Stream.empty();

  @override
  Future<TransportSendResult> send(List<int> data) async {
    return const TransportSendResult(accepted: true);
  }
}
