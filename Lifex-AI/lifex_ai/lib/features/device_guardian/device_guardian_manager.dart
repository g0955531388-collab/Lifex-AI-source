/// =============================================================
/// Lifex-AI — حماية الجهاز واستعادة الحساب
/// الملف: device_guardian_manager.dart
/// المسار: lib/features/device_guardian/device_guardian_manager.dart
/// الوصف: المدير المركزي لحماية الجهاز من الفقدان أو السرقة — يُنسّق
/// بين استعادة الحساب والأجهزة الموثوقة عند اكتشاف نشاط مشبوه.
/// =============================================================
library;

import 'account_recovery_manager.dart';
import 'trusted_devices_manager.dart';

enum DeviceThreatLevel { none, suspiciousLogin, lostDeviceReported, stolenDeviceReported }

class DeviceGuardianManager {
  DeviceGuardianManager({
    required this.recoveryManager,
    required this.trustedDevicesManager,
  });

  final AccountRecoveryManager recoveryManager;
  final TrustedDevicesManager trustedDevicesManager;

  /// الإبلاغ عن فقدان أو سرقة الجهاز — يُقفل الجهاز المفقود عن بعد
  /// (منطقياً هنا؛ التنفيذ الفعلي يتطلب اتصال شبكة لاحقاً) ويُبقي بقية
  /// الأجهزة الموثوقة فعّالة.
  void reportDeviceLostOrStolen({
    required String deviceId,
    required bool wasStolen,
  }) {
    trustedDevicesManager.revokeDevice(deviceId);
    recoveryManager.flagUrgentRecoveryNeeded(deviceId, wasStolen: wasStolen);
  }

  /// تقييم محاولة دخول جديدة من جهاز غير معروف.
  DeviceThreatLevel evaluateLoginAttempt(String deviceId) {
    if (trustedDevicesManager.isRevoked(deviceId)) {
      return DeviceThreatLevel.stolenDeviceReported;
    }
    if (!trustedDevicesManager.isKnownDevice(deviceId)) {
      return DeviceThreatLevel.suspiciousLogin;
    }
    return DeviceThreatLevel.none;
  }
}
