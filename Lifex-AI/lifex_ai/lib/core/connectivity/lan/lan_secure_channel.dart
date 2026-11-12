/// =============================================================
/// Lifex-AI — اتصال محلي
/// الملف: lan_secure_channel.dart
/// قناة بين تطبيقَي Lifex على الشبكة المحلية: TCP بإطارات طولية، وكل إطار
/// مشفّر AES-256-GCM بمفتاح اقتران يُتبادل خارج الشبكة (رمز أو QR).
/// الإطار مربوط بالجلسة واتجاهه ورقمه المتصاعد، فلا يُعاد تشغيله ولا يُرتدّ.
/// =============================================================
library lifex_ai.core.connectivity.lan.lan_secure_channel;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// رُفض الإطار: مفتاح خاطئ، أو عبث، أو إعادة تشغيل، أو مصافحة فاشلة.
class LanFrameRejected implements Exception {
  LanFrameRejected(this.reason);
  final String reason;

  @override
  String toString() => 'LanFrameRejected: $reason';
}

class LanFrame {
  const LanFrame({required this.seq, required this.payload});
  final int seq;
  final Uint8List payload;
}

/// تشفير إطار واحد. الإطار: نسخة، اتجاه، رقم (8 بايت)، nonce، نص مشفّر، MAC.
class LanFrameCipher {
  LanFrameCipher(List<int> pairingKey)
      : _key = SecretKey(List<int>.unmodifiable(pairingKey)) {
    if (pairingKey.length != 32) {
      throw ArgumentError('LAN pairing key must be 32 bytes');
    }
  }

  static const version = 1;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _headerLength = 1 + 1 + 8;

  final SecretKey _key;
  final AesGcm _aes = AesGcm.with256bits();

  Uint8List _header(int direction, int seq) {
    final header = ByteData(_headerLength)
      ..setUint8(0, version)
      ..setUint8(1, direction)
      ..setUint64(2, seq);
    return header.buffer.asUint8List();
  }

  Future<Uint8List> seal({
    required int direction,
    required int seq,
    required List<int> sessionTag,
    required List<int> payload,
  }) async {
    final header = _header(direction, seq);
    final box = await _aes.encrypt(
      payload,
      secretKey: _key,
      nonce: _aes.newNonce(),
      aad: [...header, ...sessionTag],
    );
    return Uint8List.fromList([
      ...header,
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<LanFrame> open({
    required List<int> frame,
    required int expectDirection,
    required List<int> sessionTag,
  }) async {
    if (frame.length < _headerLength + _nonceLength + _macLength) {
      throw LanFrameRejected('short_frame');
    }
    final bytes = Uint8List.fromList(frame);
    final view = ByteData.sublistView(bytes);
    if (view.getUint8(0) != version) throw LanFrameRejected('version');
    if (view.getUint8(1) != expectDirection) throw LanFrameRejected('direction');
    final seq = view.getUint64(2);
    final header = bytes.sublist(0, _headerLength);
    final nonce = bytes.sublist(_headerLength, _headerLength + _nonceLength);
    final cipherText =
        bytes.sublist(_headerLength + _nonceLength, bytes.length - _macLength);
    final mac = bytes.sublist(bytes.length - _macLength);
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: _key,
        aad: [...header, ...sessionTag],
      );
      return LanFrame(seq: seq, payload: Uint8List.fromList(clear));
    } on SecretBoxAuthenticationError {
      throw LanFrameRejected('authentication');
    }
  }

  static Uint8List newPairingKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }
}

/// سلك رسائل: TCP بطول 4 بايت قبل كل رسالة، وبحد أقصى للحجم.
class LanWire {
  LanWire(this._socket, {this.maxMessageBytes = 1 << 20}) {
    _subscription = _socket.listen(
      _onBytes,
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: true,
    );
  }

  final Socket _socket;
  final int maxMessageBytes;
  final _messages = StreamController<Uint8List>();
  final _done = Completer<void>();
  late final StreamSubscription<Uint8List> _subscription;
  final _buffer = BytesBuilder(copy: false);
  bool _closed = false;

  Stream<Uint8List> get messages => _messages.stream;
  Future<void> get done => _done.future;

  void _onBytes(Uint8List chunk) {
    _buffer.add(chunk);
    var data = _buffer.takeBytes();
    var offset = 0;
    while (data.length - offset >= 4) {
      final length = ByteData.sublistView(data, offset, offset + 4).getUint32(0);
      if (length > maxMessageBytes) {
        unawaited(close());
        return;
      }
      if (data.length - offset - 4 < length) break;
      _messages.add(Uint8List.sublistView(data, offset + 4, offset + 4 + length));
      offset += 4 + length;
    }
    if (offset < data.length) _buffer.add(Uint8List.sublistView(data, offset));
  }

  void add(List<int> message) {
    if (_closed) return;
    final length = ByteData(4)..setUint32(0, message.length);
    _socket.add([...length.buffer.asUint8List(), ...message]);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    try {
      await _socket.close();
    } catch (_) {}
    _socket.destroy();
    _finish();
  }

  void _finish() {
    _closed = true;
    if (!_messages.isClosed) unawaited(_messages.close());
    if (!_done.isCompleted) _done.complete();
  }
}

enum _Phase { awaitPeerNonce, awaitHello, awaitWelcome, open, failed }

/// مصافحة ثم قناة مشفّرة. العميل اتجاهه 0، والمضيف اتجاهه 1.
class LanSecureChannel {
  LanSecureChannel._(this._wire, this._cipher, {required this.isClient});

  static const _hello = 'LIFEX-HELLO-1';
  static const _welcome = 'LIFEX-WELCOME-1';

  final LanWire _wire;
  final LanFrameCipher _cipher;
  final bool isClient;
  _Phase _phase = _Phase.awaitPeerNonce;
  late Uint8List _myNonce;
  Uint8List _tag = Uint8List(0);
  int _outSeq = 0;
  int _inSeq = 0;
  int rejectedFrames = 0;
  final _ready = Completer<void>();
  final _payloads = StreamController<Uint8List>.broadcast();
  Future<void> _inbound = Future<void>.value();

  int get _myDirection => isClient ? 0 : 1;
  int get _peerDirection => isClient ? 1 : 0;

  Stream<Uint8List> get payloads => _payloads.stream;
  Future<void> get done => _wire.done;
  bool get isOpen => _phase == _Phase.open;

  static Future<LanSecureChannel> client(
    Socket socket,
    LanFrameCipher cipher, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _start(LanSecureChannel._(LanWire(socket), cipher, isClient: true), timeout);

  static Future<LanSecureChannel> host(
    Socket socket,
    LanFrameCipher cipher, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _start(LanSecureChannel._(LanWire(socket), cipher, isClient: false), timeout);

  static Future<LanSecureChannel> _start(
    LanSecureChannel channel,
    Duration timeout,
  ) async {
    channel._myNonce = _nonce16();
    channel._wire.messages.listen(
      (message) => channel._inbound =
          channel._inbound.then((_) => channel._handle(message)),
    );
    unawaited(channel._wire.done.then((_) => channel._closed()));
    if (channel.isClient) channel._wire.add(channel._myNonce);
    try {
      await channel._ready.future.timeout(timeout);
    } catch (error) {
      await channel.close();
      if (error is LanFrameRejected) rethrow;
      throw LanFrameRejected('handshake_${error.runtimeType}');
    }
    return channel;
  }

  static Uint8List _nonce16() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  Future<void> _handle(Uint8List message) async {
    try {
      switch (_phase) {
        case _Phase.awaitPeerNonce:
          if (message.length != 16) throw LanFrameRejected('nonce');
          if (isClient) {
            _tag = Uint8List.fromList([..._myNonce, ...message]);
            await _sendRaw(utf8.encode(_hello));
            _phase = _Phase.awaitWelcome;
          } else {
            _wire.add(_myNonce);
            _tag = Uint8List.fromList([...message, ..._myNonce]);
            _phase = _Phase.awaitHello;
          }
        case _Phase.awaitHello:
          final frame = await _openFrame(message);
          if (utf8.decode(frame.payload, allowMalformed: true) != _hello) {
            throw LanFrameRejected('hello');
          }
          await _sendRaw(utf8.encode(_welcome));
          _phase = _Phase.open;
          if (!_ready.isCompleted) _ready.complete();
        case _Phase.awaitWelcome:
          final frame = await _openFrame(message);
          if (utf8.decode(frame.payload, allowMalformed: true) != _welcome) {
            throw LanFrameRejected('welcome');
          }
          _phase = _Phase.open;
          if (!_ready.isCompleted) _ready.complete();
        case _Phase.open:
          try {
            final frame = await _openFrame(message);
            _payloads.add(frame.payload);
          } on LanFrameRejected {
            rejectedFrames++;
          }
        case _Phase.failed:
          return;
      }
    } on LanFrameRejected catch (error) {
      _phase = _Phase.failed;
      if (!_ready.isCompleted) _ready.completeError(error);
      await _wire.close();
    }
  }

  Future<LanFrame> _openFrame(Uint8List message) async {
    final frame = await _cipher.open(
      frame: message,
      expectDirection: _peerDirection,
      sessionTag: _tag,
    );
    if (frame.seq <= _inSeq) throw LanFrameRejected('replay');
    _inSeq = frame.seq;
    return frame;
  }

  Future<void> _sendRaw(List<int> payload) async {
    _outSeq++;
    _wire.add(await _cipher.seal(
      direction: _myDirection,
      seq: _outSeq,
      sessionTag: _tag,
      payload: payload,
    ));
  }

  Future<bool> send(List<int> payload) async {
    if (_phase != _Phase.open) return false;
    await _sendRaw(payload);
    return true;
  }

  void _closed() {
    if (_phase != _Phase.failed) _phase = _Phase.failed;
    if (!_ready.isCompleted) _ready.completeError(LanFrameRejected('closed'));
    if (!_payloads.isClosed) unawaited(_payloads.close());
  }

  Future<void> close() => _wire.close();
}
