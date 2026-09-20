/// =============================================================
/// Lifex-AI — توافق أجهزة
/// الملف: interoperability_engine.dart
/// لا اختراع POWER_OFF. Unknown ≠ Trusted. التحويل فقط لوحدات معروفة.
/// =============================================================
library lifex_ai.core.device_interoperability.engine;

import '../device_protocol/lifex_protocol.dart';
import '../device_protocol/protocol_packet.dart';

class CommandMapping {
  const CommandMapping({
    required this.universalCommand,
    required this.nativeCommand,
    this.parameterMapping = const {},
    this.requiresAuthorization = true,
  });

  final String universalCommand;
  final String nativeCommand;
  final Map<String, String> parameterMapping;
  final bool requiresAuthorization;
}

class UnitConverter {
  const UnitConverter();

  double? convert({
    required double value,
    required String from,
    required String to,
  }) {
    if (from == to) return value;
    if (from == 'C' && to == 'F') return value * 9 / 5 + 32;
    if (from == 'F' && to == 'C') return (value - 32) * 5 / 9;
    return null;
  }
}

class InteroperabilityResult {
  const InteroperabilityResult({
    required this.trusted,
    required this.readAvailable,
    required this.controlAvailable,
    required this.streamAvailable,
    required this.adapterKind,
    this.reason = '',
  });

  final bool trusted;
  final bool readAvailable;
  final bool controlAvailable;
  final bool streamAvailable;
  final String adapterKind;
  final String reason;
}

class DeviceInteroperabilityEngine {
  DeviceInteroperabilityEngine({
    LifexProtocol? protocol,
    this.knownMappings = const {},
    this.unitConverter = const UnitConverter(),
  }) : protocol = protocol ?? LifexProtocol();

  final LifexProtocol protocol;
  final Map<String, CommandMapping> knownMappings;
  final UnitConverter unitConverter;

  InteroperabilityResult inspect({
    required String deviceId,
    required bool knownAdapter,
    required bool genericServices,
    required bool trusted,
  }) {
    if (!trusted) {
      return const InteroperabilityResult(
        trusted: false,
        readAvailable: false,
        controlAvailable: false,
        streamAvailable: false,
        adapterKind: 'unknown',
        reason: 'unknown_not_trusted',
      );
    }
    if (knownAdapter) {
      return const InteroperabilityResult(
        trusted: true,
        readAvailable: true,
        controlAvailable: true,
        streamAvailable: true,
        adapterKind: 'known',
      );
    }
    if (genericServices) {
      return const InteroperabilityResult(
        trusted: true,
        readAvailable: true,
        controlAvailable: false,
        streamAvailable: true,
        adapterKind: 'generic_read',
        reason: 'partial_capability',
      );
    }
    return const InteroperabilityResult(
      trusted: true,
      readAvailable: true,
      controlAvailable: false,
      streamAvailable: false,
      adapterKind: 'read_only_fallback',
    );
  }

  CommandResult translateAndExecute({
    required String deviceId,
    required String universalCommand,
    Map<String, dynamic> parameters = const {},
  }) {
    final map = knownMappings[universalCommand];
    if (map == null) {
      return const CommandResult(ok: false, reason: 'unsupportedCommand');
    }
    return protocol.execute(
      CommandRequest(
        commandId: 'cmd_${DateTime.now().microsecondsSinceEpoch}',
        deviceId: deviceId,
        action: map.nativeCommand,
        timestamp: DateTime.now(),
        idempotencyKey: '${deviceId}_${map.nativeCommand}_${parameters.hashCode}',
        parameters: parameters,
      ),
    );
  }
}
