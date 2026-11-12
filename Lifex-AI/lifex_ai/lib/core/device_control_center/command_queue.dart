/// =============================================================
/// Lifex-AI — مركز التحكم
/// الملف: command_queue.dart
/// طابور لكل جهاز. الإلغاء لا يخترع نجاحاً.
/// =============================================================
library lifex_ai.core.device_control_center.command_queue;

import 'control_types.dart';

class DeviceCommandQueue {
  final _pending = <String, List<ControlCommand>>{};
  final cancelled = <String>{};

  void enqueue(ControlCommand command) {
    _pending.putIfAbsent(command.deviceId, () => []).add(command);
  }

  ControlCommand? dequeue(String deviceId) {
    final list = _pending[deviceId];
    if (list == null || list.isEmpty) return null;
    return list.removeAt(0);
  }

  bool cancel(String commandId) {
    cancelled.add(commandId);
    for (final list in _pending.values) {
      list.removeWhere((c) => c.commandId == commandId);
    }
    return true;
  }

  bool isCancelled(String commandId) => cancelled.contains(commandId);

  int lengthFor(String deviceId) => _pending[deviceId]?.length ?? 0;
}
