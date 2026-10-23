/// =============================================================
/// Lifex-AI — الاتصال بين الأجهزة
/// الملف: universal_device_connectivity_engine.dart
/// المسار: lib/features/network/universal_device_connectivity_engine.dart
/// الوصف: طبقة تجريد موحّدة فوق بلوتوث/واي فاي/USB — تسمح لبقية
/// التطبيق بطلب "اتصال بجهاز طبي" دون معرفة القناة التقنية المستخدمة.
///
/// ⚠️ ملاحظة نطاق: هذا الملف يغطي فقط الأجهزة الاستهلاكية الشخصية
/// (موازين ضغط/سكر منزلية) القابلة للاتصال عبر بلوتوث/واي فاي عادي.
/// بروتوكولات المستشفيات الصناعية (DICOM/HL7/Modbus/CAN Bus) تحتاج
/// SDKs مرخّصة من الشركات المصنّعة ولا تُبنى داخل تطبيق موبايل عادي —
/// تُدار عبر medical_protocol_translator.dart كطبقة منفصلة لاحقاً.
/// =============================================================
library;

import 'bluetooth_manager.dart';
import 'connected_devices_registry.dart';
import 'network_manager.dart';
import 'wifi_manager.dart';

enum PreferredTransport { auto, bluetoothOnly, wifiOnly }

class UniversalConnectionResult {
  final bool success;
  final String? connectedDeviceId;
  final String? errorMessageAr;

  const UniversalConnectionResult.success(this.connectedDeviceId)
      : success = true,
        errorMessageAr = null;

  const UniversalConnectionResult.failure(this.errorMessageAr)
      : success = false,
        connectedDeviceId = null;
}

/// محرك الاتصال الموحّد بالأجهزة الطبية الاستهلاكية.
class UniversalDeviceConnectivityEngine {
  UniversalDeviceConnectivityEngine({
    required this.networkManager,
    required this.bluetoothManager,
    required this.wifiManager,
    required this.registry,
  });

  final NetworkManager networkManager;
  final BluetoothManager bluetoothManager;
  final WifiManager wifiManager;
  final ConnectedDevicesRegistry registry;

  /// محاولة الاتصال بجهاز طبي معروف بمعرّفه، مع اختيار القناة تلقائياً
  /// إن لم تُحدَّد قناة مفضّلة.
  Future<UniversalConnectionResult> connectToDevice({
    required String deviceId,
    PreferredTransport transport = PreferredTransport.auto,
  }) async {
    if (transport == PreferredTransport.bluetoothOnly ||
        (transport == PreferredTransport.auto &&
            networkManager.bestAvailableChannel() ==
                ConnectivityChannel.bluetooth)) {
      final success = await bluetoothManager.connectToDevice(deviceId);
      if (success) {
        registry.markConnected(deviceId, ConnectivityChannel.bluetooth);
        return UniversalConnectionResult.success(deviceId);
      }
    }

    if (transport == PreferredTransport.wifiOnly ||
        transport == PreferredTransport.auto) {
      if (wifiManager.isSuitableForLargeTransfer) {
        // الاتصال الفعلي عبر واي فاي مباشر يتطلب معرفة معرّف المضيف؛
        // هنا نفترض أن deviceId هو نفسه معرّف المضيف لأغراض التبسيط.
        final success = await wifiManager.joinHostForDeviceHandoff(deviceId);
        if (success) {
          registry.markConnected(deviceId, ConnectivityChannel.wifi);
          return UniversalConnectionResult.success(deviceId);
        }
      }
    }

    return const UniversalConnectionResult.failure(
      'تعذّر الاتصال بالجهاز. تأكد من تفعيل البلوتوث أو الواي فاي وقرب الجهاز.',
    );
  }

  void disconnectDevice(String deviceId) {
    bluetoothManager.disconnectFromDevice(deviceId);
    registry.markDisconnected(deviceId);
  }
}
