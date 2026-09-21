/// =============================================================
/// Lifex-AI — سواقات
/// الملف: driver_registry.dart
/// =============================================================
library lifex_ai.core.device_drivers.driver_registry;

import '../connectivity/connection_device.dart';
import 'device_driver_profile.dart';
import 'universal_driver.dart';
import 'virtual_device.dart';

class DriverRegistry {
  final _drivers = <UniversalDriver>[];

  void register(UniversalDriver driver) {
    _drivers.add(driver);
  }

  UniversalDriver? findDriver(ConnectionDevice device) {
    for (final d in _drivers) {
      if (d is VirtualDevice && d.deviceId == device.id) return d;
    }
    return null;
  }

  List<UniversalDriver> get drivers => List.unmodifiable(_drivers);

  /// أجهزة اختبار. ليست كتالوج السوق العالمي.
  static DriverRegistry withSimulators() {
    final r = DriverRegistry();
    final catalog = <DeviceDriverProfile, String>{
      DriverProfiles.phone: 'sim_phone_001',
      DriverProfiles.tv: 'sim_tv_001',
      DriverProfiles.watch: 'sim_watch_001',
      DriverProfiles.camera: 'sim_camera_001',
      DriverProfiles.medical: 'sim_med_001',
      DriverProfiles.computer: 'sim_pc_001',
      DriverProfiles.speaker: 'sim_speaker_001',
      DriverProfiles.printer: 'sim_printer_001',
      DriverProfiles.vehicle: 'sim_vehicle_001',
      DriverProfiles.smartHome: 'sim_home_001',
      DriverProfiles.laboratory: 'sim_lab_001',
    };
    catalog.forEach((profile, id) {
      r.register(
        VirtualDevice(
          profile: profile,
          deviceId: id,
          displayName: 'Lifex Test ${profile.name}',
        ),
      );
    });
    r.register(
      VirtualDevice(
        profile: DriverProfiles.smartWheelchair,
        deviceId: 'sim_wheelchair_001',
        displayName: 'كرسي Lifex الذكي (محاكاة)',
      ),
    );
    r.register(
      VirtualDevice(
        profile: DriverProfiles.generic,
        deviceId: 'sim_unknown_001',
        displayName: 'جهاز غير معروف',
      ),
    );
    return r;
  }
}
