/// =============================================================
/// Lifex-AI — وضع البقاء
/// الملف: survival_energy_mode.dart
/// الصوت وإمكانية الوصول والطوارئ لا تُقيَّد هنا أبداً.
/// =============================================================

/// ميزات تبقى فعّالة حتى في أحرج ظروف البطارية.
const List<String> alwaysActiveFeatures = [
  'emergency_manager',
  'sms_fallback_channel',
  'health_alert_dispatcher',
  'voice_engine',
  'voice_accessibility',
  'emergency_communication',
  'emergency_location',
  'critical_alerts',
  'sos_channels',
];

/// وضع البقاء بالطاقة — يخفّض غير الحرج فقط.
class SurvivalEnergyMode {
  SurvivalEnergyMode({
    this.activationThresholdPercent = 15,
    this.deactivationThresholdPercent = 25,
    List<String>? restrictedFeatures,
  }) : restrictedFeatures = restrictedFeatures ??
            const [
              'smart_vision_engine',
              'remote_health_monitor',
              'background_sync',
              'background_analytics',
              'background_indexing',
              'noncritical_ai_workload',
            ];

  final int activationThresholdPercent;
  final int deactivationThresholdPercent;

  /// لا يجوز أن تحتوي أي عنصر من [alwaysActiveFeatures].
  final List<String> restrictedFeatures;

  bool _isActive = false;
  bool get isActive => _isActive;

  void activate() {
    assert(
      restrictedFeatures.every((f) => !alwaysActiveFeatures.contains(f)),
      'خطأ إعداد: لا يجوز تقييد ميزة أساسية دائمة التفعيل مثل الصوت أو الطوارئ.',
    );
    _isActive = true;
  }

  void deactivate() {
    _isActive = false;
  }
}
