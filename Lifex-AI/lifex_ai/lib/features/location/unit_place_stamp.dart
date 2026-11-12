/// موقع الوحدة من قراءة الجهاز فقط. لا شارع يُستنتج من الإحداثيات.
library lifex_ai.features.location.unit_place_stamp;

import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';
import 'nearby_care_finder.dart';

class UnitPlaceWrite {
  const UnitPlaceWrite({required this.wrote, required this.messageAr});

  final bool wrote;
  final String messageAr;
}

class UnitPlaceStamp {
  const UnitPlaceStamp();

  static const seats = {
    'hospital',
    'healthUnit',
    'lab',
    'labs',
    'imaging',
    'radiology',
    'pharmacy',
    'dental',
    'doctor',
    'doctors',
  };

  static bool isUnitSeat(String seat) => seats.contains(seat);

  UnitPlaceWrite writeDeviceFix({
    required HealthProfile unit,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String knownAddress = '',
    DateTime? at,
  }) {
    if (!isUnitSeat(unit.billingSeat)) {
      return const UnitPlaceWrite(
        wrote: false,
        messageAr: 'هذا ملف شخص وليس وحدة صحية. لم يُكتب موقع وحدة.',
      );
    }
    if (!NearbyCareFinder.usableFix(latitude, longitude)) {
      return const UnitPlaceWrite(
        wrote: false,
        messageAr: 'الإحداثيات غير صالحة. لم يُكتب شيء في ملف الوحدة.',
      );
    }
    final address = knownAddress.trim();
    final record = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'addressText': address,
      'addressKnown': address.isNotEmpty,
      'source': 'device',
      'recordedAt': (at ?? DateTime.now()).toIso8601String(),
      'profileId': unit.profileId,
    };
    ProfileBoxStore(unit).setMap(BoxKeys.unitOwnPlace, record);
    final line = address.isEmpty
        ? 'كُتبت إحداثيات الجهاز في ملف الوحدة. العنوان النصي غير موجود، والإحداثيات لا تُحوَّل إلى شارع.'
        : 'كُتبت إحداثيات الجهاز في ملف الوحدة. العنوان المعروف في الملف: $address.';
    return UnitPlaceWrite(wrote: true, messageAr: line);
  }

  static Map<String, dynamic>? placeOf(HealthProfile profile) {
    final map = ProfileBoxStore(profile).map(BoxKeys.unitOwnPlace);
    final lat = map['latitude'];
    final lon = map['longitude'];
    if (lat is! num || lon is! num) return null;
    if (!NearbyCareFinder.usableFix(lat.toDouble(), lon.toDouble())) {
      return null;
    }
    return map;
  }

  static List<Map<String, dynamic>> rowsFromProfiles(
    Iterable<HealthProfile> profiles,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final profile in profiles) {
      if (!isUnitSeat(profile.billingSeat)) continue;
      final place = placeOf(profile);
      if (place == null) continue;
      final known = place['addressKnown'] == true;
      final address = (place['addressText'] ?? '').toString();
      rows.add({
        'title': profile.fullName,
        'detail': known && address.isNotEmpty
            ? address
            : 'إحداثيات وحدة بلا عنوان نصي',
        'latitude': place['latitude'],
        'longitude': place['longitude'],
        'profileId': profile.profileId,
        'seat': profile.billingSeat,
      });
    }
    return rows;
  }
}
