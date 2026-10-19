/// =============================================================
/// Lifex-AI — اتصال لاسلكي
/// الملف: nfc_manager.dart
/// NFC لاقتران قصير. ليس نقل بيانات ضخمة.
/// =============================================================
library lifex_ai.core.connectivity.wireless.nfc_manager;

import '../../connection_state.dart';

class NfcDevice {
  const NfcDevice({this.tagId = ''});
  final String tagId;
}

class NfcManager {
  const NfcManager();

  Future<NfcDevice?> readTag() async => null;

  Future<ConnectionState> bootstrapPairing() async {
    return ConnectionState.unbound;
  }
}
