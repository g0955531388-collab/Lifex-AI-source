/// =============================================================
/// Lifex-AI — أقرب رعاية من موقع مقروء
/// المسافة تُحسب من إحداثيات الجهاز وإحداثيات السجل فقط.
/// =============================================================
library lifex_ai.features.location.nearby_care_finder;

import 'dart:math' as math;

class CareBox {
  const CareBox({
    required this.kindAr,
    required this.rows,
    this.specialtyApplies = false,
  });

  final String kindAr;
  final List<Map<String, dynamic>> rows;
  final bool specialtyApplies;
}

class RankedCarePlace {
  const RankedCarePlace({
    required this.kindAr,
    required this.title,
    required this.detail,
    required this.km,
  });

  final String kindAr;
  final String title;
  final String detail;
  final double? km;

  bool get ranked => km != null;
}

class NearbyCareReport {
  const NearbyCareReport({
    required this.doctors,
    required this.units,
  });

  final List<RankedCarePlace> doctors;
  final List<RankedCarePlace> units;
}

class NearbyCareFinder {
  const NearbyCareFinder();

  static double? readCoord(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final parsed = value is num ? value.toDouble() : double.tryParse('$value');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool usableFix(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0 && longitude == 0) return false;
    return true;
  }

  static double distanceKm({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    const earthKm = 6371.0;
    double rad(double degree) => degree * math.pi / 180;
    final dLat = rad(toLat - fromLat);
    final dLon = rad(toLon - fromLon);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(fromLat)) *
            math.cos(rad(toLat)) *
            math.pow(math.sin(dLon / 2), 2);
    return earthKm * 2 * math.asin(math.sqrt(a.toDouble()));
  }

  NearbyCareReport suggest({
    required double? hereLat,
    required double? hereLon,
    required String? specialty,
    required List<CareBox> boxes,
  }) {
    final doctors = <RankedCarePlace>[];
    final units = <RankedCarePlace>[];
    final hereOk = hereLat != null &&
        hereLon != null &&
        usableFix(hereLat, hereLon);
    for (final box in boxes) {
      for (final row in box.rows) {
        final title = (row['title'] ?? row['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final detail = (row['detail'] ?? '').toString();
        final specialtyText = row['specialty']?.toString() ?? '';
        if (specialty != null &&
            specialty.isNotEmpty &&
            !detail.contains(specialty) &&
            !title.contains(specialty) &&
            specialtyText != specialty) {
          continue;
        }
        final lat = readCoord(row, const ['latitude', 'lat']);
        final lon = readCoord(row, const ['longitude', 'lng', 'lon']);
        double? km;
        if (hereOk &&
            lat != null &&
            lon != null &&
            usableFix(lat, lon)) {
          km = distanceKm(
            fromLat: hereLat,
            fromLon: hereLon,
            toLat: lat,
            toLon: lon,
          );
        }
        final place = RankedCarePlace(
          kindAr: box.kindAr,
          title: title,
          detail: detail,
          km: km,
        );
        if (box.specialtyApplies) {
          doctors.add(place);
        } else {
          units.add(place);
        }
      }
    }
    int compare(RankedCarePlace a, RankedCarePlace b) {
      if (a.km == null && b.km == null) return a.title.compareTo(b.title);
      if (a.km == null) return 1;
      if (b.km == null) return -1;
      return a.km!.compareTo(b.km!);
    }

    doctors.sort(compare);
    units.sort(compare);
    return NearbyCareReport(doctors: doctors, units: units);
  }
}
