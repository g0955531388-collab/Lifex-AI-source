/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: control_stage.dart
/// التعرف ليس اتصالاً، والاتصال ليس تحكماً.
/// =============================================================
library lifex_ai.core.device_lab.control_stage;

enum DeviceControlStage {
  identified,
  connected,
  authorized,
  controllable,
}

extension DeviceControlStageX on DeviceControlStage {
  bool get mayRead => this.index >= DeviceControlStage.connected.index;
  bool get mayControl => this == DeviceControlStage.controllable;
}
