/// =============================================================
/// Lifex-AI — سواقات
/// الملف: market_catalog_hint.dart
/// اسم أو نوع من كتالوج سوقي. تصنيف اكتشاف فقط.
/// المسار drivers/… لا يُحمَّل. التحكم الثنائي مرفوض.
/// DISCOVERED ≠ CONNECTED ≠ AUTHORIZED ≠ CONTROLABLE
/// =============================================================
library lifex_ai.core.device_drivers.market_catalog_hint;

import 'device_driver_profile.dart';

class MarketCatalogHint {
  const MarketCatalogHint({
    required this.profile,
    required this.refused,
    required this.noteAr,
  });

  final DeviceDriverProfile? profile;
  final bool refused;

  /// نص للمستخدم. ليس أمر جهاز.
  final String noteAr;

  static const bilateralControlAllowed = false;
  static const driverPathLoaded = false;
  static const controlable = false;
  static const readingIsDiagnosis = false;

  static MarketCatalogHint fromRecord(Map<String, dynamic> row) {
    final type = _fold(
      '${row['type'] ?? row['category'] ?? row['kind'] ?? ''}',
    );
    final name = _fold('${row['name'] ?? row['model'] ?? ''}');
    final blob = '$type $name';
    if (_refused(blob)) {
      return const MarketCatalogHint(
        profile: null,
        refused: true,
        noteAr:
            'هذا النوع خارج التحكم. وجوده في الكتالوج لا يثبّت تعريفاً ولا يمنح إذناً.',
      );
    }
    final profile = _profileFor(blob);
    if (profile == null) {
      return const MarketCatalogHint(
        profile: DriverProfiles.generic,
        refused: false,
        noteAr: 'اسم غير مربوط بقالب. يبقى غير معروف وغير قابل للتحكم.',
      );
    }
    if (profile == DriverProfiles.medical) {
      return MarketCatalogHint(
        profile: profile,
        refused: false,
        noteAr:
            'مطابقة اسم لقياس محتمل. القراءة ملاحظة وليست تشخيصاً، والكتالوج لا يشغّل الجهاز.',
      );
    }
    return MarketCatalogHint(
      profile: profile,
      refused: false,
      noteAr:
          'مطابقة نوع على قالب ${profile.category}. ليست اتصالاً ولا تفويضاً ولا تحكماً.',
    );
  }

  static bool _refused(String blob) {
    const needles = [
      'lock',
      'payment',
      'pos',
      'chip programmer',
      'radio transceiver',
      'hackrf',
      'sdr',
      'plc',
      'industrial',
      'drone',
      'flight controller',
      'robot',
      'defibrillator',
      'ventilator',
      'infusion',
      'syringe pump',
      'surgical',
      'anesthesia',
      'autoclave',
      'incubator',
    ];
    return _has(blob, needles);
  }

  static DeviceDriverProfile? _profileFor(String blob) {
    if (_has(blob, const [
      'glucometer',
      'glucose',
      'oximeter',
      'spo2',
      'blood pressure',
      'thermometer',
      'ecg',
      'medical',
      'cpap',
      'hearing',
      'spirometer',
      'nebulizer',
      'accu-chek',
      'nonin',
      'dexcom',
      'freestyle',
      'omron',
      'withings',
      'contec',
      'polar',
    ])) {
      return DriverProfiles.medical;
    }
    if (_has(blob, const [
      'phone',
      'smartphone',
      'mobile',
      'iphone',
      'tablet',
      'ipad',
    ])) {
      return DriverProfiles.phone;
    }
    if (_has(blob, const [
      'laptop',
      'desktop',
      'computer',
      'keyboard',
      'mouse',
      'pc',
    ])) {
      return DriverProfiles.computer;
    }
    if (_has(blob, const ['watch', 'wearable', 'band', 'smartwatch'])) {
      return DriverProfiles.watch;
    }
    if (_has(blob, const ['camera', 'webcam'])) return DriverProfiles.camera;
    if (_has(blob, const ['tv', 'display', 'monitor', 'screen'])) {
      return DriverProfiles.tv;
    }
    if (_has(blob, const ['speaker', 'headset', 'audio', 'earbud'])) {
      return DriverProfiles.speaker;
    }
    if (_has(blob, const ['printer', 'scanner'])) return DriverProfiles.printer;
    if (_has(blob, const ['vehicle', 'car', 'obd'])) {
      return DriverProfiles.vehicle;
    }
    if (_has(blob, const [
      'smart_home',
      'smart home',
      'plug',
      'light',
      'thermostat',
      'fridge',
      'washer',
      'oven',
    ])) {
      return DriverProfiles.smartHome;
    }
    if (_has(blob, const ['lab', 'centrifuge'])) {
      return DriverProfiles.laboratory;
    }
    return null;
  }

  static bool _has(String blob, List<String> needles) {
    final tokens = blob.split(' ').toSet();
    for (final needle in needles) {
      if (needle.contains(' ')) {
        if (blob.contains(needle)) return true;
      } else if (tokens.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static String _fold(String raw) =>
      raw.toLowerCase().replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');
}
