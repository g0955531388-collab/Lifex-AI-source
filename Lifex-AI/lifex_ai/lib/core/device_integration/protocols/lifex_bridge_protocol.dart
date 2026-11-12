/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: lifex_bridge_protocol.dart
/// بروتوكول جسر Lifex (LBP): رسائل JSON بين Lifex وجسر عتاد أو تطبيق Lifex آخر.
///   cmd   {t,id,action,params,ts}      من Lifex
///   ack   {t,id,ok,reason?}             تأكيد تنفيذ من الجهاز
///   state {t,values}                    حالة الجهاز
///   event {t,kind,payload}              حدث
///   reading {t,channel,value,unit?,kind?}  قراءة حساس
///   caps  {t,actions:[...]}             الأوامر التي يعلنها الجهاز بنفسه
/// على النقل المتدفق (تسلسلي/TCP/BLE) كل رسالة سطر ينتهي بـ \n.
/// =============================================================
library lifex_ai.core.device_integration.protocols.lifex_bridge_protocol;

import 'dart:convert';

import '../../device_drivers/device_command.dart';
import 'byte_stream_decoder.dart';

class LbpMessage {
  const LbpMessage._();

  static List<int> encode(Map<String, Object?> message) =>
      utf8.encode(jsonEncode(message));

  static Map<String, dynamic>? decode(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  /// أمر يحمل بيانات صحية يحتاج مرجع موافقة.
  static String? healthDataRefusal(Map<String, dynamic> parameters) {
    final carriesHealth = parameters['containsHealthData'] == true;
    final consent = parameters['consentRef'];
    if (carriesHealth && (consent is! String || consent.trim().isEmpty)) {
      return 'health_data_without_consent';
    }
    return null;
  }
}

enum LbpFraming { message, lines }

class LbpCodec implements ByteStreamDecoder<Map<String, dynamic>> {
  LbpCodec(this.framing, {this.maxMessageBytes = 64 * 1024});

  final LbpFraming framing;
  final int maxMessageBytes;
  final _line = <int>[];
  int _rejected = 0;

  @override
  String get protocolName => 'lbp1';

  @override
  int get rejected => _rejected;

  @override
  void reset() => _line.clear();

  @override
  List<Map<String, dynamic>> feed(List<int> bytes) {
    if (framing == LbpFraming.message) {
      return _decodeOne(bytes);
    }
    final out = <Map<String, dynamic>>[];
    for (final b in bytes) {
      if (b == 0x0A) {
        if (_line.isNotEmpty) out.addAll(_decodeOne(_line));
        _line.clear();
      } else if (_line.length >= maxMessageBytes) {
        _rejected++;
        _line.clear();
      } else {
        _line.add(b);
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _decodeOne(List<int> bytes) {
    if (bytes.length > maxMessageBytes) {
      _rejected++;
      return const [];
    }
    final message = LbpMessage.decode(bytes);
    if (message == null || message['t'] is! String) {
      _rejected++;
      return const [];
    }
    return [message];
  }

  List<int> encode(Map<String, Object?> message) {
    final body = LbpMessage.encode(message);
    return framing == LbpFraming.message ? body : [...body, 0x0A];
  }

  List<int> encodeCommand(DeviceCommand command) => encode({
        't': 'cmd',
        'id': command.id,
        'action': command.action,
        'params': command.parameters,
        'ts': command.timestamp.toUtc().toIso8601String(),
      });
}
