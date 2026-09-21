/// =============================================================
/// Lifex-AI — محوّلات أدوات MCP (Adapters)
/// لا نجاح وهمي: غير الموصول → TOOL_UNAVAILABLE.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_tool_adapters;

import 'mcp_errors.dart';
import 'mcp_live_handlers.dart';
import 'mcp_request_context.dart';
import 'mcp_tool_contract.dart';
import '../ci_evidence/github_ci_evidence_reader.dart';

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

/// GitHub: قراءة CI عبر [GitHubCiEvidenceReader] — بلا كتابة.
class GitHubMcpToolAdapter implements McpToolAdapter {
  GitHubMcpToolAdapter({
    GitHubCiEvidenceReader? evidenceReader,
  }) : evidenceReader =
            evidenceReader ?? const UnavailableGitHubCiEvidenceReader();

  final GitHubCiEvidenceReader evidenceReader;

  @override
  String get toolId => 'mcp.github';

  @override
  Future<McpAdapterOutcome> execute({
    required McpGatewayRequest request,
    required McpToolContract contract,
  }) async {
    if (contract.isWrite(request.requestedAction)) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.forbidden.wireName,
        messageAr: 'FORBIDDEN — محوّل GitHub في هذه المرحلة READ ONLY.',
        errorCode: McpErrorCode.forbidden,
      );
    }

    if (request.requestedAction == 'ping') {
      return McpAdapterOutcome(
        ok: true,
        status: 'OK',
        messageAr: evidenceReader.isAvailable
            ? 'محوّل GitHub جاهز للقراءة.'
            : 'محوّل GitHub مسجّل — الخادم الحي غير موصول.',
        data: {
          'connected': evidenceReader.isAvailable,
          'adapterReady': true,
          'allowsWrite': evidenceReader.allowsWrite,
        },
        provenance: {
          'adapter': toolId,
          'liveRemote': evidenceReader.isAvailable,
        },
      );
    }

    const readOps = {
      'read_ci_evidence',
      'read_workflow_status',
      'read_workflow_jobs',
      'read_artifacts',
      'read_repository',
      'read_branches',
      'read_commits',
      'read_files',
    };

    if (!readOps.contains(request.requestedAction)) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.toolValidationFailed.wireName,
        messageAr: 'عملية غير مدعومة للقراءة: ${request.requestedAction}',
        errorCode: McpErrorCode.toolValidationFailed,
      );
    }

    if (!evidenceReader.isAvailable) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.toolUnavailable.wireName,
        messageAr:
            'TOOL_UNAVAILABLE — GitHub CI غير موصول. لا يُدّعى نجاح قراءة الأدلة.',
        errorCode: McpErrorCode.toolUnavailable,
      );
    }

    final repo = (request.arguments['repository'] as String?) ??
        request.resource;
    if (repo.trim().isEmpty) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.invalidRequest.wireName,
        messageAr: 'repository مطلوب لقراءة أدلة CI.',
        errorCode: McpErrorCode.invalidRequest,
      );
    }

    final fetch = await evidenceReader.fetchCiEvidence(
      repository: repo,
      workflowRunId: request.arguments['workflowRunId'] as String?,
      commitSha: request.arguments['commitSha'] as String?,
      branch: request.arguments['branch'] as String?,
    );

    if (fetch.status == GitHubEvidenceFetchStatus.unavailable) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.toolUnavailable.wireName,
        messageAr: fetch.messageAr ?? 'TOOL_UNAVAILABLE',
        errorCode: McpErrorCode.toolUnavailable,
      );
    }

    if (!fetch.isOk || fetch.evidence == null) {
      return McpAdapterOutcome(
        ok: false,
        status: McpErrorCode.executionFailed.wireName,
        messageAr: fetch.messageAr ?? 'تعذّر جلب أدلة CI.',
        errorCode: McpErrorCode.executionFailed,
        data: {'found': false},
      );
    }

    final e = fetch.evidence!;
    return McpAdapterOutcome(
      ok: true,
      status: 'OK',
      messageAr: 'أُحضرت أدلة CI (READ ONLY).',
      data: {
        'repository': e.repository,
        'workflowRunId': e.workflowRunId,
        'workflowName': e.workflowName,
        'workflowStatus': e.workflowStatus,
        'conclusion': e.conclusion,
        'branch': e.branch,
        'commitSha': e.commitSha,
        'event': e.event,
        'jobNames': e.jobNames,
        'jobStatuses': e.jobStatuses,
        'analyzeResult': e.analyzeResult.name,
        'testResult': e.testResult.name,
        'apkBuildResult': e.apkBuildResult.name,
        'artifactName': e.artifact?.name,
        'artifactId': e.artifact?.id,
        'artifactDigest': e.artifact?.digestOrSha256,
        'source': e.source,
      },
      provenance: {
        'adapter': toolId,
        'readOnly': true,
        'allowsWrite': false,
        ...e.provenance,
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
