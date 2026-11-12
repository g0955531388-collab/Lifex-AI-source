/// =============================================================
/// Lifex-AI — الطاقة والاستدامة
/// الملف: battery_monitor.dart
/// المسار: lib/features/energy/battery_monitor.dart
/// الوصف: تتبّع حالة البطارية (المستوى، الشحن من عدمه) وإعلام بقية
/// وحدات الطاقة بأي تغيّر. التنفيذ الفعلي لقراءة البطارية من نظام
/// التشغيل يُربط لاحقاً عبر [BatteryReader]؛ هذا الملف تنظيمي فقط.
/// =============================================================
library;

class BatteryStatus {
  final int level; // 0-100
  final bool isCharging;
  final DateTime readAt;

  BatteryStatus({
    required this.level,
    required this.isCharging,
    DateTime? readAt,
  }) : readAt = readAt ?? DateTime.now();
}

/// عقد أي قارئ بطارية فعلي (سيُنفَّذ عبر حزمة مثل battery_plus لاحقاً).
abstract class BatteryReader {
  Future<int> currentLevel();
  Future<bool> isCharging();
  Stream<BatteryStatus> statusStream();
}

typedef BatteryStatusListener = void Function(BatteryStatus status);

/// مراقب البطارية المركزي.
class BatteryMonitor {
  BatteryMonitor({this.reader});

  final BatteryReader? reader;
  final List<BatteryStatusListener> _listeners = [];

  BatteryStatus _lastKnownStatus =
      BatteryStatus(level: 100, isCharging: false);

  bool _hasDeviceReading = false;

  bool get hasDeviceReading => _hasDeviceReading;

  BatteryStatus get lastKnownStatus => _lastKnownStatus;

  void addListener(BatteryStatusListener listener) => _listeners.add(listener);
  void removeListener(BatteryStatusListener listener) =>
      _listeners.remove(listener);

  /// تحديث الحالة يدوياً (يُستدعى من مستمع stream فعلي عند ربط
  /// [BatteryReader] حقيقي، أو من الاختبارات).
  void updateStatus(BatteryStatus status) {
    _hasDeviceReading = true;
    _lastKnownStatus = status;
    for (final listener in List<BatteryStatusListener>.from(_listeners)) {
      listener(status);
    }
  }

  /// بدء الاستماع لتيار حالة البطارية من القارئ الفعلي، إن وُجد.
  void startMonitoring() {
    reader?.statusStream().listen(updateStatus);
  }
}
