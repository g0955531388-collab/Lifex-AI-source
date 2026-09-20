/// =============================================================
/// Lifex-AI — محوّلات أدوات MCP (Adapters)
/// لا نجاح وهمي: غير الموصول → TOOL_UNAVAILABLE.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_tool_adapters;

import 'mcp_errors.dart';
import 'mcp_live_handlers.dart';
import 'mcp_request_context.dart';
import 'mcp_tool_contract.dart';

class McpAdapterOutcome {
  const McpAdapterOutcome({
    required this.ok,
    required this.status,
    required this.messageAr,
    this.data = const {},
    this.errorCode,
    this.provenance,
  });

  final bool ok;
  final String status;
  final String messageAr;
  final Map<String, Object?> data;
  final McpErrorCode? errorCode;
  final Map<String, Object?>? provenance;
}

abstract class McpToolAdapter {
  String get toolId;

  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  });
}

class FilesMcpToolAdapter implements McpToolAdapter {
  FilesMcpToolAdapter({McpLiveFoundationHandlers? handlers})
      : _handlers = handlers ?? const McpLiveFoundationHandlers();

  final McpLiveFoundationHandlers _handlers;

  @override
  String get toolId => 'mcp.local_files';

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    final args = <String, Object?>{
      ...request.arguments,
      'action': request.requestedAction,
      if (request.resource.isNotEmpty) 'path': request.resource,
    };
    final r = await _handlers.localFiles(args);
    if (!r.ok) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.executionFailed.wireName,
        messageAr: r.messageAr,
        errorCode: McpErrorCode.executionFailed,
        data: r.payload,
      );
    }
    return McpAdapterOutcome(
      ok: true,
      status: 'OK',
      messageAr: r.messageAr,
      data: r.payload,
      provenance: {
        'adapter': toolId,
        'transport': 'inProcess',
        'live': true,
      },
    );
  }
}

/// GitHub: قراءة غير موصولة بخادم حي → TOOL_UNAVAILABLE (صادق).
class GitHubMcpToolAdapter implements McpToolAdapter {
  @override
  String get toolId => 'mcp.github';

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    if (request.requestedAction == 'ping') {
      return const McpAdapterOutcome(
        ok: true,
        status: 'OK',
        messageAr: 'محوّل GitHub مسجّل — الخادم الحي غير موصول.',
        data: {'connected': false, 'adapterReady': true},
        provenance: {'adapter': 'mcp.github', 'liveRemote': false},
      );
    }
    return McpAdapterOutcome(
      ok: false,
      status: McpErrorCode.toolUnavailable.wireName,
      messageAr:
          'TOOL_UNAVAILABLE — GitHub MCP غير موصول بخادم حي. لا يُدّعى نجاح قراءة CI/Repo.',
      errorCode: McpErrorCode.toolUnavailable,
      data: {
        'requestedAction': request.requestedAction,
        'supportedWhenLive': contract.allowedOperations,
      },
    );
  }
}

class CursorMcpToolAdapter implements McpToolAdapter {
  @override
  String get toolId => 'mcp.cursor';

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    if (request.requestedAction == 'ping') {
      return const McpAdapterOutcome(
        ok: true,
        status: 'OK',
        messageAr: 'محوّل Cursor مسجّل — التنفيذ الحر ممنوع؛ الخادم غير موصول.',
        data: {'connected': false, 'mayMutateMain': false},
      );
    }
    return McpAdapterOutcome(
      ok: false,
      status: McpErrorCode.toolUnavailable.wireName,
      messageAr:
          'TOOL_UNAVAILABLE — Cursor Agent MCP غير موصول. لا تنفيذ حر عبر Gateway.',
      errorCode: McpErrorCode.toolUnavailable,
    );
  }
}

class BrowserMcpToolAdapter implements McpToolAdapter {
  @override
  String get toolId => 'mcp.browser';

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    if (request.requestedAction == 'ping') {
      return const McpAdapterOutcome(
        ok: true,
        status: 'OK',
        messageAr: 'محوّل Browser مسجّل — البحث الحي غير موصول.',
        data: {'connected': false},
      );
    }
    if (contract.isWrite(request.requestedAction)) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.forbidden.wireName,
        messageAr: 'عمليات الشراء/الدفع/الإرسال محظورة على Browser Tool.',
        errorCode: McpErrorCode.forbidden,
      );
    }
    return McpAdapterOutcome(
      ok: false,
      status: McpErrorCode.toolUnavailable.wireName,
      messageAr: 'TOOL_UNAVAILABLE — Browser MCP غير موصول كخادم حي.',
      errorCode: McpErrorCode.toolUnavailable,
    );
  }
}

class DevicesMcpToolAdapter implements McpToolAdapter {
  @override
  String get toolId => 'mcp.devices';

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    return McpAdapterOutcome(
      ok: false,
      status: McpErrorCode.toolUnavailable.wireName,
      messageAr:
          'TOOL_UNAVAILABLE — لا تحكم طبي في هذه المرحلة. Device MCP غير موصول.',
      errorCode: McpErrorCode.toolUnavailable,
    );
  }
}

/// مهلة قابلة للحقن في الاختبارات.
class TimeoutMcpToolAdapter implements McpToolAdapter {
  TimeoutMcpToolAdapter({
    required this.toolId,
    required this.delay,
  });

  @override
  final String toolId;
  final Duration delay;

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    await Future<void>.delayed(delay);
    return const McpAdapterOutcome(
      ok: true,
      status: 'OK',
      messageAr: 'تأخر مقصود للاختبار',
    );
  }
}

class McpToolAdapterHub {
  McpToolAdapterHub({Map<String, McpToolAdapter>? adapters})
      : _adapters = Map.of(adapters ?? _defaults);

  final Map<String, McpToolAdapter> _adapters;

  static final Map<String, McpToolAdapter> _defaults = {
    'mcp.local_files': FilesMcpToolAdapter(),
    'mcp.github': GitHubMcpToolAdapter(),
    'mcp.cursor': CursorMcpToolAdapter(),
    'mcp.browser': BrowserMcpToolAdapter(),
    'mcp.devices': DevicesMcpToolAdapter(),
  };

  McpToolAdapter? of(String toolId) => _adapters[toolId];

  void replace(String toolId, McpToolAdapter adapter) {
    _adapters[toolId] = adapter;
  }
}

/// يغلف استدعاء المحوّل بمهلة العقد.
Future<McpAdapterOutcome> runAdapterWithTimeout({
  required McpToolAdapter adapter,
  required McpGatewayRequest request,
  required McpToolContract contract,
}) async {
  try {
    return await adapter
        .execute(request: request, contract: contract)
        .timeout(contract.timeout, onTimeout: () {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.toolTimeout.wireName,
        messageAr: 'TOOL_TIMEOUT — تجاوزت الأداة ${contract.timeout.inSeconds}ث.',
        errorCode: McpErrorCode.toolTimeout,
      );
    });
  } catch (e) {
    return McpAdapterOutcome(
      ok: false,
      status: McpErrorCode.executionFailed.wireName,
      messageAr: 'EXECUTION_FAILED — $e',
      errorCode: McpErrorCode.executionFailed,
    );
  }
}
