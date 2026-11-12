/// =============================================================
/// Lifex-AI — مختبر أجهزة
/// الملف: virtual_display.dart
/// محتوى شاشة محاكاة. ليس مرآة لجهاز حقيقي.
/// =============================================================
library lifex_ai.core.device_lab.virtual_display;

class VirtualDisplay {
  String content = '';

  Future<void> show(String value) async {
    content = value;
  }

  Future<void> clear() async {
    content = '';
  }
}

class VirtualSensor {
  VirtualSensor(this.name, {this.unit = '', this.simulated = true});

  final String name;
  final String unit;
  final bool simulated;
  Object? value;

  void setSimulated(Object next) {
    value = next;
  }
}
