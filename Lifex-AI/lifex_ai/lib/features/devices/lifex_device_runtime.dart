/// =============================================================
/// Lifex-AI — تشغيل منظومة الأجهزة في طبقة التطبيق
/// الملف: lifex_device_runtime.dart
/// UI/Voice → Runtime → ControlCenter → Protocol → Driver
/// =============================================================
library lifex_ai.features.devices.lifex_device_runtime;

import '../../core/connectivity/connection_device.dart';
import '../../core/connectivity/connection_state.dart';
import '../../core/device_control_center/control_types.dart';
import '../../core/device_control_center/device_control_center.dart';
import '../../core/device_drivers/device_command.dart';
import '../../core/device_drivers/device_driver_profile.dart';
import '../../core/device_drivers/lifex_device_hub.dart';
import '../../core/device_drivers/smart_wheelchair_profile.dart';
import '../../core/device_drivers/virtual_device.dart';
import '../../core/device_protocol/lifex_protocol.dart';
import '../../core/device_protocol/packet_type.dart';
import '../../core/device_services/service_types.dart';

enum AndroidTransportSupport {
  supported,
  partiallySupported,
  unavailable,
  osRestricted,
  hardwareRestricted,
  requiresUserAction,
  architectureOnly,
}

class TransportCapabilityReport {
  const TransportCapabilityReport({
    required this.transport,
    required this.support,
    required this.noteAr,
  });

  final String transport;
  final AndroidTransportSupport support;
  final String noteAr;
}

class DeviceVoiceOutcome {
  const DeviceVoiceOutcome({
    required this.spokenAr,
    required this.spokenEn,
    required this.ok,
    this.result,
  });

  final String spokenAr;
  final String spokenEn;
  final bool ok;
  final ControlCommandResult? result;
}

/// واجهة التطبيق الوحيدة لمنظومة الأجهزة المستعادة.
class LifexDeviceRuntime {
  LifexDeviceRuntime({
    LifexDeviceHub? hub,
    LifexProtocol? protocol,
  }) : hub = hub ?? LifexDeviceHub(),
       protocol = protocol ?? LifexProtocol() {
    controlCenter = DeviceControlCenter(protocol: this.protocol);
  }

  final LifexDeviceHub hub;
  final LifexProtocol protocol;
  late final DeviceControlCenter controlCenter;

  bool _wheelchairAttached = false;
  bool _wheelchairControllable = false;
  bool emergencyClear = true;
  bool obstacleBlocksMotion = false;
  String? _pendingMotionCommandId;

  List<TransportCapabilityReport> transportMatrix() => const [
        TransportCapabilityReport(
          transport: 'USB',
          support: AndroidTransportSupport.requiresUserAction,
          noteAr:
              'يتطلب USB Host وموافقة المستخدم لكل جهاز. لا صلاحية مطلقة.',
        ),
        TransportCapabilityReport(
          transport: 'Bluetooth Classic',
          support: AndroidTransportSupport.partiallySupported,
          noteAr: 'يحتاج BLUETOOTH_CONNECT/SCAN وAdapter فعلي لكل بروتوكول.',
        ),
        TransportCapabilityReport(
          transport: 'BLE',
          support: AndroidTransportSupport.partiallySupported,
          noteAr: 'مسح/اتصال وقت التشغيل؛ الخلفية مقيّدة حسب Android.',
        ),
        TransportCapabilityReport(
          transport: 'Wi-Fi',
          support: AndroidTransportSupport.partiallySupported,
          noteAr: 'شبكة محلية/سحابة حسب Adapter؛ ليس تحكماً راديوياً مطلقاً.',
        ),
        TransportCapabilityReport(
          transport: 'Wi-Fi Direct',
          support: AndroidTransportSupport.architectureOnly,
          noteAr: 'بنية جاهزة؛ لا Adapter مُثبت في هذه النسخة.',
        ),
        TransportCapabilityReport(
          transport: 'NFC',
          support: AndroidTransportSupport.partiallySupported,
          noteAr: 'قراءة/اقتران قصيرة المدى عند توفر العتاد والإذن.',
        ),
        TransportCapabilityReport(
          transport: 'Virtual / Lab',
          support: AndroidTransportSupport.supported,
          noteAr: 'محاكاة كاملة للاختبار دون ادعاء عتاد حقيقي.',
        ),
      ];

  Future<List<ConnectionDevice>> discover() => hub.discover();

  List<DashboardTile> dashboard() => controlCenter.dashboard();

  VirtualDevice? _wheelchairDriver() {
    for (final d in hub.registry.drivers) {
      if (d is VirtualDevice &&
          d.deviceId == SmartWheelchairDeviceProfile.deviceId) {
        return d;
      }
    }
    return null;
  }

  Future<DeviceVoiceOutcome> attachSimulatedWheelchair({
    bool grantControl = true,
  }) async {
    var wc = _wheelchairDriver();
    if (wc == null) {
      wc = VirtualDevice(
        profile: DriverProfiles.smartWheelchair,
        deviceId: SmartWheelchairDeviceProfile.deviceId,
        displayName: 'كرسي Lifex الذكي (محاكاة)',
      );
      hub.registry.register(wc);
    }

    final device = wc.connection;
    final caps = SmartWheelchairDeviceProfile.protocolCapabilities();
    final stage = protocol.stageOf(device.id);

    if (stage == ProtocolSessionStage.discovered) {
      protocol.identify(device.id, caps: caps);
    }
    if (protocol.stageOf(device.id) == ProtocolSessionStage.identified) {
      protocol.connect(device.id);
    }
    if (protocol.stageOf(device.id) == ProtocolSessionStage.connected) {
      protocol.authenticate(device.id, credentialsOk: true);
    }
    if (protocol.stageOf(device.id) == ProtocolSessionStage.authenticated) {
      protocol.authorize(device.id, scopes: {PermissionScope.read});
    }
    if (grantControl &&
        protocol.stageOf(device.id) == ProtocolSessionStage.authorized) {
      protocol.grantControl(device.id, scopes: {PermissionScope.control});
    }

    await hub.connect(device);

    final controllable =
        protocol.stageOf(device.id) == ProtocolSessionStage.controllable;
    final scopes = <AccessScope>{
      AccessScope.read,
      AccessScope.discover,
      if (controllable) AccessScope.control,
      if (controllable) AccessScope.execute,
    };

    controlCenter.adoptService(
      SmartWheelchairDeviceProfile.mobilityService(
        connected: true,
        trusted: true,
        scopes: scopes,
      ),
    );
    controlCenter.attachDevice(
      ManagedDevice(
        deviceId: device.id,
        name: wc.displayName,
        category: SmartWheelchairDeviceProfile.category,
        status: controllable
            ? DeviceControlStatus.authorized
            : DeviceControlStatus.connected,
        authenticated: true,
        authorized: controllable,
      ),
    );

    _wheelchairAttached = true;
    _wheelchairControllable = controllable;
    protocol.snapshots[device.id] = {
      'motion': 'stopped',
      'speed': 0,
      'batteryPercent': 86,
      'obstacle': false,
      'position': 'home',
      'executedOnHardware': false,
      'realHardwareAdapterBound':
          SmartWheelchairDeviceProfile.realHardwareAdapterBound,
    };

    return DeviceVoiceOutcome(
      spokenAr: controllable
          ? 'الكرسي الذكي المحاكى متصل ومصرّح للتحكم. ليس عتاداً مادياً.'
          : 'الكرسي معرّف ومتصل دون صلاحية تحكم بعد.',
      spokenEn: controllable
          ? 'Simulated smart wheelchair connected and controllable. Not real hardware.'
          : 'Wheelchair identified and connected without control grant.',
      ok: true,
    );
  }

  Future<DeviceVoiceOutcome> listConnectedSpoken() async {
    final tiles = dashboard();
    if (tiles.isEmpty) {
      return const DeviceVoiceOutcome(
        spokenAr: 'لا توجد أجهزة مُدارة حالياً في مركز التحكم.',
        spokenEn: 'No managed devices in the control center yet.',
        ok: true,
      );
    }
    final ar = tiles.map((t) => '${t.title}: ${t.statusLabel}').join('. ');
    return DeviceVoiceOutcome(
      spokenAr: 'الأجهزة: $ar',
      spokenEn: 'Devices: $ar',
      ok: true,
    );
  }

  Future<DeviceVoiceOutcome> wheelchairStatusSpoken() async {
    if (!_wheelchairAttached) {
      return const DeviceVoiceOutcome(
        spokenAr: 'الكرسي غير مرفق. قل: أظهر الكرسي، أو افتح مركز الأجهزة.',
        spokenEn: 'Wheelchair not attached. Say show wheelchair.',
        ok: false,
      );
    }
    final snap = protocol.readState(SmartWheelchairDeviceProfile.deviceId);
    final bat = snap?.values['batteryPercent'] ?? '?';
    final motion = snap?.values['motion'] ?? 'unknown';
    return DeviceVoiceOutcome(
      spokenAr:
          'الكرسي ${_wheelchairControllable ? 'قابل للتحكم' : 'متصل دون تحكم'}. '
          'الحركة: $motion. البطارية: $bat بالمئة. محاكاة وليست عتاداً حقيقياً.',
      spokenEn:
          'Wheelchair ${_wheelchairControllable ? 'controllable' : 'connected only'}. '
          'Motion: $motion. Battery: $bat%. Simulation only.',
      ok: true,
    );
  }

  Future<DeviceVoiceOutcome> confirmPendingMotion() async {
    final id = _pendingMotionCommandId;
    if (id == null) {
      return const DeviceVoiceOutcome(
        spokenAr: 'لا يوجد أمر حركة بانتظار التأكيد.',
        spokenEn: 'No pending motion to confirm.',
        ok: false,
      );
    }
    final result = await controlCenter.confirm(id);
    _pendingMotionCommandId = null;
    if (result.ok || result.stateVerified) {
      await _syncDriverFromSnapshot();
    }
    return DeviceVoiceOutcome(
      spokenAr: result.ok
          ? 'تم تأكيد الحركة والتحقق من الحالة. ليست حركة عتاد حقيقي.'
          : 'تعذّر التأكيد: ${result.reason}',
      spokenEn: result.ok
          ? 'Motion confirmed and verified. Not real hardware.'
          : 'Confirm failed: ${result.reason}',
      ok: result.ok,
      result: result,
    );
  }

  Future<DeviceVoiceOutcome> runWheelchairAction(
    String action, {
    Map<String, dynamic>? parameters,
    bool userConfirmed = false,
  }) async {
    if (!_wheelchairAttached) {
      final attach = await attachSimulatedWheelchair();
      if (!attach.ok) return attach;
    }
    final cls = SmartWheelchairDeviceProfile.classify(action);
    if (!_wheelchairControllable && cls != WheelchairCommandClass.read) {
      return const DeviceVoiceOutcome(
        spokenAr: 'الكرسي غير مصرّح للتحكم. امنح التحكم أولاً.',
        spokenEn: 'Wheelchair not authorized for control.',
        ok: false,
      );
    }

    if (cls == WheelchairCommandClass.motionControl) {
      if (!emergencyClear) {
        return const DeviceVoiceOutcome(
          spokenAr:
              'حالة الطوارئ غير صافية. الحركة مرفوضة. استخدم إيقاف الطوارئ.',
          spokenEn: 'Emergency state not clear. Motion refused.',
          ok: false,
        );
      }
      if (obstacleBlocksMotion) {
        return const DeviceVoiceOutcome(
          spokenAr: 'سياسة العوائق تمنع الحركة. أوقف أو أزل العائق أولاً.',
          spokenEn: 'Obstacle policy blocks motion.',
          ok: false,
        );
      }
    }

    if (cls == WheelchairCommandClass.read) {
      final snap = protocol.readState(SmartWheelchairDeviceProfile.deviceId);
      final key = switch (action) {
        'READ_BATTERY' => 'batteryPercent',
        'READ_SPEED' => 'speed',
        'READ_OBSTACLE' => 'obstacle',
        'READ_POSITION' => 'position',
        _ => 'motion',
      };
      final value = snap?.values[key];
      return DeviceVoiceOutcome(
        spokenAr: 'قراءة $action: $value. محاكاة.',
        spokenEn: 'Read $action: $value. Simulated.',
        ok: true,
      );
    }

    final params = <String, dynamic>{
      ...?parameters,
      if (cls == WheelchairCommandClass.motionControl) 'motion': action,
      if (action == 'STOP' || action == 'EMERGENCY_STOP') 'motion': 'stopped',
      if (action == 'STOP' || action == 'EMERGENCY_STOP') 'speed': 0,
      'executedOnHardware': false,
    };

    final commandId =
        'wc_${action}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await controlCenter.submit(
      ControlCommand(
        commandId: commandId,
        deviceId: SmartWheelchairDeviceProfile.deviceId,
        serviceId: SmartWheelchairDeviceProfile.mobilityServiceId,
        action: action,
        parameters: params,
        risk: SmartWheelchairDeviceProfile.riskFor(action),
        requiresConfirmation: cls == WheelchairCommandClass.motionControl,
        confirmed: userConfirmed,
      ),
      userConfirmed: userConfirmed,
    );

    if (result.status == CommandStatus.awaitingConfirmation) {
      _pendingMotionCommandId = commandId;
      return DeviceVoiceOutcome(
        spokenAr:
            'أمر الحركة $action يحتاج تأكيداً صوتياً. قل: أكّد الحركة.',
        spokenEn: 'Motion $action needs confirmation. Say confirm motion.',
        ok: false,
        result: result,
      );
    }

    if (result.executedOnDevice || result.ok) {
      await _syncDriver(action, params);
    }

    final verified = result.stateVerified || result.ok;
    return DeviceVoiceOutcome(
      spokenAr: verified
          ? 'تم تنفيذ $action والتحقق من الحالة. ليست حركة عتاد حقيقي.'
          : 'أمر $action: ${result.status.name}. السبب: ${result.reason}',
      spokenEn: verified
          ? '$action executed and state verified. Not real hardware motion.'
          : '$action: ${result.status.name}. ${result.reason}',
      ok: verified,
      result: result,
    );
  }

  Future<void> _syncDriver(
    String action,
    Map<String, dynamic> parameters,
  ) async {
    final driver = _wheelchairDriver();
    if (driver == null) return;
    if (driver.connection.state != ConnectionState.connected) return;
    await driver.sendCommand(
      DeviceCommand(
        id: 'drv_$action',
        deviceId: driver.deviceId,
        action: action,
        timestamp: DateTime.now(),
        parameters: parameters,
      ),
    );
  }

  Future<void> _syncDriverFromSnapshot() async {
    final snap = protocol.readState(SmartWheelchairDeviceProfile.deviceId);
    final motion = '${snap?.values['motion'] ?? 'STOP'}';
    await _syncDriver(motion, Map<String, dynamic>.from(snap?.values ?? {}));
  }
}
