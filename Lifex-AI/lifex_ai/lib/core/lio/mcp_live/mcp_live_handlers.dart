/// =============================================================
/// Lifex-AI — معالجات In-Process لأساس MCP Live
/// صادق: local_files حي محدود؛ الباقي REQUIRES_EXTERNAL_SETUP.
/// =============================================================
library lifex_ai.core.lio.mcp_live.mcp_live_handlers;

import 'mcp_transport.dart';

/// كلمات تُرفض في مسارات الملفات — حماية Foundation من تسريب سريري/أسرار.
const kMcpLiveForbiddenPathTokens = <String>[
  'patient',
  'clinical',
  'phi',
  '.env',
  'secret',
  'credential',
  'private_key',
  'مريض',
  'سريري',
];

class McpLiveFoundationHandlers {
  const McpLiveFoundationHandlers();

  Map<String, McpInProcessHandler> build() => {
        'mcp.local_files': localFiles,
        'mcp.github': externalStub('GitHub MCP'),
        'mcp.cursor': externalStub('Cursor Agent MCP'),
        'mcp.browser': externalStub('Browser MCP'),
        'mcp.devices': externalStub('Devices MCP'),
      };

  McpInProcessHandler externalStub(String label) {
    return (arguments) async => McpTransportCallResult(
          ok: false,
          requiresExternalSetup: true,
          messageAr:
              'REQUIRES_EXTERNAL_SETUP — $label غير موصول كخادم MCP حي بعد. '
              'الجلسة والسياسة جاهزتان؛ التنفيذ الخارجي مرحلة لاحقة.',
          payload: {'argumentsKeys': arguments.keys.toList()},
        );
  }

  Future<McpTransportCallResult> localFiles(
    Map<String, Object?> arguments,
  ) async {
    final action = (arguments['action'] as String?)?.trim() ?? 'ping';
    final path = (arguments['path'] as String?)?.trim() ?? '';

    if (action == 'ping') {
      return const McpTransportCallResult(
        ok: true,
        messageAr: 'mcp.local_files جاهز (In-Process Foundation).',
        payload: {'live': true, 'transport': 'inProcess'},
      );
    }

    if (action == 'stat' || action == 'read_meta') {
      if (path.isEmpty) {
        return const McpTransportCallResult(
          ok: false,
          messageAr: 'path مطلوب لـ stat/read_meta.',
        );
      }
      final lower = path.toLowerCase();
      for (final token in kMcpLiveForbiddenPathTokens) {
        if (lower.contains(token)) {
          return McpTransportCallResult(
            ok: false,
            messageAr:
                'مرفوض: المسار يلمس رمزاً محظوراً ($token). '
                'Clinical/secrets خارج MCP Live Foundation.',
            payload: {'path': path},
          );
        }
      }
      return McpTransportCallResult(
        ok: true,
        messageAr: 'meta مسموح لهذا المسار ضمن Foundation (بلا قراءة محتوى).',
        payload: {
          'path': path,
          'contentRead': false,
          'note': 'قراءة المحتوى الكامل مرحلة لاحقة بعد Roots/Policy أدق.',
        },
      );
    }

    return McpTransportCallResult(
      ok: false,
      messageAr: 'إجراء غير مدعوم في Foundation: $action',
      payload: {'supported': const ['ping', 'stat', 'read_meta']},
    );
  }
}
