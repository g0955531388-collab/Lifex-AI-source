/// =============================================================
/// Lifex-AI — رسم دلالي للأجهزة
/// الملف: semantic_types.dart
/// المعرفة ليست تحكّماً. المنطق بالقدرة الموحّدة لا بالشركة.
/// =============================================================
library lifex_ai.core.device_intelligence.semantic_types;

enum GraphNodeKind {
  device,
  service,
  capability,
  transport,
  dataStream,
  displaySink,
  event,
  protocol,
}

enum GraphEdgeKind {
  hosts,
  provides,
  usesTransport,
  produces,
  canRender,
  emits,
  connectedVia,
  sameCapability,
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.kind,
    this.universalType = '',
    this.label = '',
    this.vendorHint = '',
    this.modelHint = '',
    this.attributes = const {},
  });

  final String id;
  final GraphNodeKind kind;
  final String universalType;
  final String label;
  final String vendorHint;
  final String modelHint;
  final Map<String, dynamic> attributes;
}

class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.kind,
    required this.fromId,
    required this.toId,
    this.authorized = false,
    this.hardwareBound = false,
  });

  final String id;
  final GraphEdgeKind kind;
  final String fromId;
  final String toId;
  final bool authorized;
  final bool hardwareBound;
}

class SemanticPath {
  const SemanticPath({
    required this.nodeIds,
    required this.edgeKinds,
    this.usable = false,
    this.blockReason = '',
  });

  final List<String> nodeIds;
  final List<GraphEdgeKind> edgeKinds;
  final bool usable;
  final String blockReason;
}
