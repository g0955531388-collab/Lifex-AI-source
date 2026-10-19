/// =============================================================
/// Lifex-AI — سجل خدمات
/// الملف: device_service_registry.dart
/// السجل ≠ التفويض. الترتيب تقني وليس حكماً طبياً.
/// فقدان النبض ≠ تعطّل الجهاز.
/// =============================================================
library lifex_ai.core.device_services.device_service_registry;

import 'service_record.dart';
import 'service_types.dart';

class DeviceServiceRegistry {
  DeviceServiceRegistry({this.version = const RegistryVersion()});

  final RegistryVersion version;
  final _services = <String, ServiceRecord>{};
  final _personalLabels = <String, String>{};
  int _revision = 0;

  int get revision => _revision;

  void register(ServiceRecord record) {
    _services[record.serviceId] = record;
    record.updatedAt = DateTime.now();
    _revision++;
  }

  void applyServiceUpdate(ServiceRecord record) => register(record);

  void setPersonalLabel(String serviceId, String label) {
    _personalLabels[serviceId] = label;
    final s = _services[serviceId];
    if (s != null) s.personalLabel = label;
  }

  ServiceRecord? byId(String serviceId) => _services[serviceId];

  List<ServiceRecord> all() => _services.values.toList();

  List<ServiceRecord> connectedDevices() {
    return _services.values.where((s) => s.connected).toList();
  }

  List<ServiceMatch> query(CapabilityQuery q) {
    final want = canonicalizeCapability(q.capability);
    final out = <ServiceMatch>[];
    for (final s in _services.values) {
      CapabilityRecord? cap;
      for (final c in s.capabilities) {
        if (c.universalId == want) {
          cap = c;
          break;
        }
      }
      if (cap == null) continue;
      if (q.requireRead && !cap.readable) {
        out.add(ServiceMatch(
          record: s,
          usable: false,
          exclusionReason: 'capability_not_readable',
        ));
        continue;
      }
      if (q.requireWrite && !cap.writable) {
        out.add(ServiceMatch(
          record: s,
          usable: false,
          exclusionReason: 'capability_not_writable',
        ));
        continue;
      }
      if (q.requireControl && !cap.controllable) {
        out.add(ServiceMatch(
          record: s,
          usable: false,
          exclusionReason: 'capability_not_controllable',
        ));
        continue;
      }
      if (q.requireStream && !cap.streamable) {
        out.add(ServiceMatch(
          record: s,
          usable: false,
          exclusionReason: 'capability_not_streamable',
        ));
        continue;
      }
      final gate = _gate(s, q);
      out.add(ServiceMatch(
        record: s,
        usable: gate == '',
        exclusionReason: gate,
        rankScore: gate == '' ? _technicalRank(s) : 0,
      ));
    }
    out.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return out;
  }

  List<ServiceRecord> findUsable(CapabilityQuery q) {
    return query(q).where((m) => m.usable).map((m) => m.record).toList();
  }

  String _gate(ServiceRecord s, CapabilityQuery q) {
    if (s.status == ServiceStatus.disconnected ||
        s.status == ServiceStatus.unavailable) {
      return 'service_unavailable';
    }
    if (!s.connected) return 'not_connected';
    if (!s.trusted) return 'not_trusted';
    if (s.status == ServiceStatus.unauthorized) return 'unauthorized';
    if (q.requireRead && !s.allows(AccessScope.read)) return 'no_read_permission';
    if (q.requireStream && !s.allows(AccessScope.stream)) {
      return 'no_stream_permission';
    }
    if (q.requireControl && !s.allows(AccessScope.control)) {
      return 'no_control_permission';
    }
    if (s.status == ServiceStatus.busy) return 'busy';
    if (s.status == ServiceStatus.degraded) {
      // listed but not preferred
    }
    return '';
  }

  /// ترتيب تقني: اتصال، صلاحية، جودة بيانات، زمن، إشارة. ليس أفضلية طبية.
  int _technicalRank(ServiceRecord s) {
    var n = 0;
    if (s.connected) n += 40;
    if (s.allows(AccessScope.read)) n += 20;
    n += switch (s.dataQuality) {
      DataQuality.excellent => 15,
      DataQuality.good => 12,
      DataQuality.fair => 6,
      DataQuality.poor => 2,
      _ => 0,
    };
    if (s.latencyMs != null) n += (200 - s.latencyMs!.clamp(0, 200)) ~/ 20;
    if (s.signalStrength != null) n += (s.signalStrength!.clamp(0, 1) * 10).round();
    if (s.virtual) n -= 5;
    return n;
  }

  HeartbeatHealth noteHeartbeat({
    required String serviceId,
    required bool responded,
  }) {
    final s = _services[serviceId];
    if (s == null) return HeartbeatHealth.unknown;
    s.heartbeat = responded ? HeartbeatHealth.healthy : HeartbeatHealth.lost;
    if (!responded && s.status == ServiceStatus.available) {
      s.status = ServiceStatus.degraded;
    }
    return s.heartbeat;
  }
}

class ServiceRouter {
  ServiceRouter(this.registry);

  final DeviceServiceRegistry registry;

  ServiceRecord? findService(String capability) {
    final usable = registry.findUsable(
      CapabilityQuery(capability: capability, requireRead: true),
    );
    return usable.isEmpty ? null : usable.first;
  }

  Map<String, dynamic> read(ServiceRecord service) {
    if (!service.allows(AccessScope.read)) {
      return {'ok': false, 'reason': 'unauthorized'};
    }
    if (!service.connected) {
      return {'ok': false, 'reason': 'not_connected'};
    }
    return {
      'ok': true,
      'deviceId': service.deviceId,
      'serviceId': service.serviceId,
      'clinicalInterpretation': false,
      'dataQuality': service.dataQuality.name,
    };
  }

  Map<String, dynamic> execute({
    required ServiceRecord service,
    required String command,
  }) {
    if (!service.allows(AccessScope.execute) &&
        !service.allows(AccessScope.control)) {
      return {'ok': false, 'reason': 'unauthorized'};
    }
    final known = service.commands.any((c) => c.commandId == command);
    if (!known) return {'ok': false, 'reason': 'unsupportedCommand'};
    return {'ok': true, 'command': command, 'executedOnDevice': service.virtual};
  }
}
