/// =============================================================
/// Lifex-AI — اتصال
/// الملف: connection_state.dart
/// الحالة. connected لا تُعلَن بلا جلسة حية.
/// =============================================================
library lifex_ai.core.connectivity.connection_state;

enum ConnectionState {
  disconnected,
  discovering,
  connecting,
  pairing,
  authenticating,
  connected,
  reconnecting,
  error,
  unbound,
}
