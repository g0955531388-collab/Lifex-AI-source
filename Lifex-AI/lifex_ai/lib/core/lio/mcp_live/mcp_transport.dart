/// =============================================================
/// Lifex-AI — MCP Live Transport
/// واجهة النقل + تنفيذ In-Process للأساس الحي.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_transport;

import 'mcp_live_types.dart';

/// نتيجة استدعاء على طبقة النقل فقط (بعد اجتياز السياسة).
class McpTransportCallResult {
  const McpTransportCallResult({
    required this.ok,
    required this.messageAr,
    this.payload = const {},
    this.requiresExternalSetup = false,
  });

  final bool ok;
  final String messageAr;
  final Map<String, Object?> payload;
  final bool requiresExternalSetup;
}

typedef McpInProcessHandler = Future<McpTransportCallResult> Function(
  Map<String, Object?> arguments,
);

/// عقد النقل — لا يطبّق سياسة LIO (ذلك في Live Gateway).
abstract class McpLiveTransport {
  McpTransportKind get kind;

  Future<void> connect();

  Future<void> disconnect();

  bool get isConnected;

  Future<McpTransportCallResult> callTool({
    required String toolId,
    required Map<String, Object?> arguments,
  });
}

/// نقل حي داخل العملية — أساس Foundation.
class InProcessMcpTransport implements McpLiveTransport {
  InProcessMcpTransport({
    Map<String, McpInProcessHandler>? handlers,
  }) : _handlers = Map.of(handlers ?? {});

  final Map<String, McpInProcessHandler> _handlers;
  bool _connected = false;

  @override
  McpTransportKind get kind => McpTransportKind.inProcess;

  @override
  bool get isConnected => _connected;

  void registerHandler(String toolId, McpInProcessHandler handler) {
    _handlers[toolId] = handler;
  }

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<McpTransportCallResult> callTool({
    required String toolId,
    required Map<String, Object?> arguments,
  }) async {
    if (!_connected) {
      return const McpTransportCallResult(
        ok: false,
        messageAr: 'النقل غير متصل.',
      );
    }
    final handler = _handlers[toolId];
    if (handler == null) {
      return McpTransportCallResult(
        ok: false,
        requiresExternalSetup: true,
        messageAr:
            'REQUIRES_EXTERNAL_SETUP — لا يوجد معالج In-Process للأداة $toolId.',
      );
    }
    return handler(arguments);
  }
}

/// نقل HTTP/SSE — هيكل فقط حتى يُضبط endpoint حقيقي.
class HttpSseMcpTransport implements McpLiveTransport {
  HttpSseMcpTransport({this.endpoint});

  final Uri? endpoint;
  bool _connected = false;

  @override
  McpTransportKind get kind => McpTransportKind.httpSse;

  @override
  bool get isConnected => _connected && endpoint != null;

  @override
  Future<void> connect() async {
    if (endpoint == null) {
      _connected = false;
      return;
    }
    // لا اتصال شبكة وهمي — التفعيل عند وجود endpoint فقط كعلامة جلسة.
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<McpTransportCallResult> callTool({
    required String toolId,
    required Map<String, Object?> arguments,
  }) async {
    if (endpoint == null) {
      return const McpTransportCallResult(
        ok: false,
        requiresExternalSetup: true,
        messageAr:
            'REQUIRES_EXTERNAL_SETUP — لم يُضبط endpoint لـ MCP HTTP/SSE.',
      );
    }
    if (!_connected) {
      return const McpTransportCallResult(
        ok: false,
        messageAr: 'جلسة HTTP/SSE غير متصلة.',
      );
    }
    return McpTransportCallResult(
      ok: false,
      requiresExternalSetup: true,
      messageAr:
          'REQUIRES_EXTERNAL_SETUP — النقل HTTP/SSE للـ $toolId غير موصول بخادم MCP حي بعد.',
      payload: {'endpoint': endpoint.toString()},
    );
  }
}
