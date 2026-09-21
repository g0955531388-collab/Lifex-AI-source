/// =============================================================
/// Lifex-AI — رسم دلالي للأجهزة
/// الملف: device_semantic_graph.dart
/// ECG خدمة على جهاز، عبر نقل، تنتج تياراً، وشاشة أخرى قد تعرضه.
/// =============================================================
library lifex_ai.core.device_intelligence.device_semantic_graph;

import '../connectivity/connection_type.dart';
import '../device_services/service_record.dart';
import '../device_services/service_types.dart';
import 'semantic_types.dart';

class DeviceSemanticGraph {
  final nodes = <String, GraphNode>{};
  final edges = <GraphEdge>[];

  void putNode(GraphNode node) => nodes[node.id] = node;

  void putEdge(GraphEdge edge) {
    edges.removeWhere((e) => e.id == edge.id);
    edges.add(edge);
  }

  /// إدخال من السجل 46 دون استخدام اسم الشركة كمفتاح منطقي.
  void ingestService(
    ServiceRecord service, {
    ConnectionType transport = ConnectionType.virtual,
    bool hardwareBound = false,
  }) {
    final deviceId = 'device:${service.deviceId}';
    putNode(
      GraphNode(
        id: deviceId,
        kind: GraphNodeKind.device,
        universalType: service.category.name,
        label: service.personalLabel ?? service.deviceId,
        vendorHint: '${service.deviceId}',
      ),
    );
    final svcId = 'service:${service.serviceId}';
    putNode(
      GraphNode(
        id: svcId,
        kind: GraphNodeKind.service,
        universalType: service.name.toUpperCase(),
        label: service.name,
      ),
    );
    putEdge(
      GraphEdge(
        id: 'hosts:$deviceId->$svcId',
        kind: GraphEdgeKind.hosts,
        fromId: deviceId,
        toId: svcId,
        authorized: service.allows(AccessScope.read) ||
            service.allows(AccessScope.control),
      ),
    );
    final tId = 'transport:${transport.name}';
    putNode(
      GraphNode(
        id: tId,
        kind: GraphNodeKind.transport,
        universalType: transport.name,
        label: transport.name,
      ),
    );
    putEdge(
      GraphEdge(
        id: 'via:$deviceId->$tId',
        kind: GraphEdgeKind.connectedVia,
        fromId: deviceId,
        toId: tId,
        hardwareBound: hardwareBound,
      ),
    );
    putEdge(
      GraphEdge(
        id: 'uses:$svcId->$tId',
        kind: GraphEdgeKind.usesTransport,
        fromId: svcId,
        toId: tId,
        hardwareBound: hardwareBound,
      ),
    );
    for (final cap in service.capabilities) {
      final cId = 'cap:${cap.universalId}';
      putNode(
        GraphNode(
          id: cId,
          kind: GraphNodeKind.capability,
          universalType: cap.universalId,
          label: cap.nativeId,
        ),
      );
      putEdge(
        GraphEdge(
          id: 'provides:$svcId->$cId',
          kind: GraphEdgeKind.provides,
          fromId: svcId,
          toId: cId,
          authorized: cap.readable || cap.streamable,
        ),
      );
      if (cap.streamable) {
        final streamId = 'stream:${service.serviceId}';
        putNode(
          GraphNode(
            id: streamId,
            kind: GraphNodeKind.dataStream,
            universalType: cap.universalId,
            label: 'stream',
          ),
        );
        putEdge(
          GraphEdge(
            id: 'produces:$svcId->$streamId',
            kind: GraphEdgeKind.produces,
            fromId: svcId,
            toId: streamId,
          ),
        );
      }
    }
    if (service.category == ServiceCategory.display) {
      final sink = 'sink:${service.deviceId}';
      putNode(
        GraphNode(
          id: sink,
          kind: GraphNodeKind.displaySink,
          universalType: 'DISPLAY',
          label: service.name,
        ),
      );
      putEdge(
        GraphEdge(
          id: 'hosts-sink:$deviceId->$sink',
          kind: GraphEdgeKind.hosts,
          fromId: deviceId,
          toId: sink,
        ),
      );
    }
  }

  /// شاشة تستطيع عرض تيار من نوع قدرة موحّد (مثل ECG).
  void linkSinkCanRender({
    required String sinkDeviceId,
    required String streamCapability,
    bool authorized = false,
  }) {
    final sink = 'sink:$sinkDeviceId';
    if (!nodes.containsKey(sink)) {
      putNode(
        GraphNode(
          id: sink,
          kind: GraphNodeKind.displaySink,
          universalType: 'DISPLAY',
        ),
      );
    }
    for (final n in nodes.values.where(
      (n) =>
          n.kind == GraphNodeKind.dataStream &&
          n.universalType == streamCapability,
    )) {
      putEdge(
        GraphEdge(
          id: 'render:$sink->${n.id}',
          kind: GraphEdgeKind.canRender,
          fromId: sink,
          toId: n.id,
          authorized: authorized,
        ),
      );
    }
  }

  List<GraphNode> servicesProviding(String universalCapability) {
    final cap = canonicalizeCapability(universalCapability);
    final capId = 'cap:$cap';
    final out = <GraphNode>[];
    for (final e in edges) {
      if (e.kind == GraphEdgeKind.provides && e.toId == capId) {
        final n = nodes[e.fromId];
        if (n != null) out.add(n);
      }
    }
    return out;
  }

  List<GraphNode> devicesHostingService(String serviceNodeId) {
    return edges
        .where((e) => e.kind == GraphEdgeKind.hosts && e.toId == serviceNodeId)
        .map((e) => nodes[e.fromId])
        .whereType<GraphNode>()
        .toList();
  }

  String? transportOf(String deviceOrServiceId) {
    for (final e in edges) {
      if ((e.kind == GraphEdgeKind.connectedVia ||
              e.kind == GraphEdgeKind.usesTransport) &&
          e.fromId == deviceOrServiceId) {
        return nodes[e.toId]?.universalType;
      }
    }
    return null;
  }

  SemanticPath? streamToDisplay({
    required String streamCapability,
  }) {
    final streams = nodes.values.where(
      (n) =>
          n.kind == GraphNodeKind.dataStream &&
          n.universalType == canonicalizeCapability(streamCapability),
    );
    for (final stream in streams) {
      for (final e in edges) {
        if (e.kind == GraphEdgeKind.canRender && e.toId == stream.id) {
          return SemanticPath(
            nodeIds: [stream.id, e.fromId],
            edgeKinds: const [GraphEdgeKind.canRender],
            usable: e.authorized,
            blockReason: e.authorized ? '' : 'graph_is_not_authorization',
          );
        }
      }
    }
    return null;
  }

  /// استعلام بالمفهوم لا بالشركة.
  bool matchesVendorAgnostic(String query) {
    final q = canonicalizeCapability(query);
    return nodes.values.any(
      (n) =>
          n.kind == GraphNodeKind.capability && n.universalType == q,
    );
  }
}
