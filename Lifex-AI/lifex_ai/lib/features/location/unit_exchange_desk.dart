/// تبادل نص طلب بين الوحدات على هذا الجهاز. ليس تشخيصاً ولا ملفاً كاملاً.
library lifex_ai.features.location.unit_exchange_desk;

import '../network_box/profile_box_store.dart';
import '../network_box/unit_membership_desk.dart';
import '../profile/health_profile.dart';
import 'nearby_care_finder.dart';
import 'unit_place_stamp.dart';

class UnitExchangeResult {
  const UnitExchangeResult({
    required this.ok,
    required this.messageAr,
    this.packetId,
  });

  final bool ok;
  final String messageAr;
  final String? packetId;
}

String _knownAddress(Map<String, dynamic>? place) {
  if (place == null || place['addressKnown'] != true) return '';
  return (place['addressText'] ?? '').toString();
}

class UnitRecipient {
  const UnitRecipient({
    required this.profile,
    required this.specialtyMatch,
    this.distanceKm,
  });

  final HealthProfile profile;
  final bool specialtyMatch;
  final double? distanceKm;
}

class UnitExchangeDesk {
  const UnitExchangeDesk();

  static const purposes = {
    'doctorRequest',
    'lab',
    'imaging',
    'pharmacy',
    'dental',
    'transfer',
  };

  static const purposeMarks = {
    'lab': {'lab', 'labs'},
    'imaging': {'imaging', 'radiology'},
    'pharmacy': {'pharmacy'},
    'dental': {'dental'},
    'doctorRequest': {'doctor', 'doctors', 'hospital', 'healthUnit'},
    'transfer': {'hospital', 'healthUnit'},
  };

  static const _memberUnits = [
    'labs',
    'radiology',
    'pharmacy',
    'dental',
    'doctors',
    'hospital',
  ];

  static String fold(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp('[ً-ْ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Set<String> marksOf(HealthProfile profile) {
    final marks = <String>{profile.billingSeat.trim()};
    final written = profile.questionnaireData['unitSpecialty'];
    if (written is String && written.trim().isNotEmpty) {
      marks.add(written.trim());
    }
    final store = ProfileBoxStore(profile);
    const membership = UnitMembershipDesk();
    for (final unitId in _memberUnits) {
      if (membership.isMember(store, unitId, profile.profileId)) {
        marks.add(unitId);
      }
    }
    marks.removeWhere((item) => item.isEmpty);
    return marks;
  }

  bool accepts(HealthProfile profile) =>
      UnitPlaceStamp.isUnitSeat(profile.billingSeat) ||
      marksOf(profile).any(purposeMarks.values.expand((item) => item).contains);

  List<UnitRecipient> findRecipients({
    required HealthProfile from,
    required List<HealthProfile> profiles,
    required String purpose,
    String query = '',
  }) {
    final wanted = purposeMarks[purpose] ?? const <String>{};
    final needle = fold(query);
    final origin = UnitPlaceStamp.placeOf(from);
    final rows = <UnitRecipient>[];
    for (final unit in profiles) {
      if (unit.profileId == from.profileId || !accepts(unit)) continue;
      final marks = marksOf(unit);
      final specialty = marks.any(wanted.contains);
      if (needle.isNotEmpty) {
        final id = fold(unit.profileId);
        final name = fold(unit.fullName);
        final hit = id == needle || id.contains(needle) || name.contains(needle);
        if (!hit) continue;
      }
      rows.add(
        UnitRecipient(
          profile: unit,
          specialtyMatch: specialty,
          distanceKm: _km(origin, UnitPlaceStamp.placeOf(unit)),
        ),
      );
    }
    rows.sort((a, b) {
      if (a.specialtyMatch != b.specialtyMatch) {
        return a.specialtyMatch ? -1 : 1;
      }
      final ad = a.distanceKm;
      final bd = b.distanceKm;
      if (ad == null && bd == null) {
        return a.profile.fullName.compareTo(b.profile.fullName);
      }
      if (ad == null) return 1;
      if (bd == null) return -1;
      final gap = ad.compareTo(bd);
      if (gap != 0) return gap;
      return a.profile.fullName.compareTo(b.profile.fullName);
    });
    return rows;
  }

  UnitRecipient? nearestSpecialist({
    required HealthProfile from,
    required List<HealthProfile> profiles,
    required String purpose,
  }) {
    for (final row in findRecipients(
      from: from,
      profiles: profiles,
      purpose: purpose,
    )) {
      if (row.specialtyMatch) return row;
    }
    return null;
  }

  double? _km(Map<String, dynamic>? origin, Map<String, dynamic>? place) {
    if (origin == null || place == null) return null;
    return NearbyCareFinder.distanceKm(
      fromLat: (origin['latitude'] as num).toDouble(),
      fromLon: (origin['longitude'] as num).toDouble(),
      toLat: (place['latitude'] as num).toDouble(),
      toLon: (place['longitude'] as num).toDouble(),
    );
  }

  HealthProfile? nearestUnit({
    required HealthProfile from,
    required List<HealthProfile> profiles,
  }) {
    final origin = UnitPlaceStamp.placeOf(from);
    HealthProfile? best;
    double? bestKm;
    for (final unit in profiles) {
      if (unit.profileId == from.profileId) continue;
      if (!UnitPlaceStamp.isUnitSeat(unit.billingSeat)) continue;
      final place = UnitPlaceStamp.placeOf(unit);
      if (origin == null || place == null) {
        best ??= unit;
        continue;
      }
      final km = NearbyCareFinder.distanceKm(
        fromLat: (origin['latitude'] as num).toDouble(),
        fromLon: (origin['longitude'] as num).toDouble(),
        toLat: (place['latitude'] as num).toDouble(),
        toLon: (place['longitude'] as num).toDouble(),
      );
      if (bestKm == null || km < bestKm) {
        best = unit;
        bestKm = km;
      }
    }
    return best;
  }

  NearbyCareReport suggest({
    required double? hereLat,
    required double? hereLon,
    required List<HealthProfile> profiles,
  }) {
    return const NearbyCareFinder().suggest(
      hereLat: hereLat,
      hereLon: hereLon,
      specialty: null,
      boxes: [
        CareBox(
          kindAr: 'وحدة',
          rows: UnitPlaceStamp.rowsFromProfiles(profiles),
        ),
      ],
    );
  }

  UnitExchangeResult send({
    required HealthProfile from,
    required HealthProfile to,
    required String purpose,
    required String text,
    required bool patientAllowsShare,
    String patientProfileId = '',
    DateTime? at,
  }) {
    if (!patientAllowsShare) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'لا تبادل بلا موافقة صاحب الملف. لم يُرسل شيء.',
      );
    }
    final body = text.trim();
    if (body.isEmpty) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'نص الطلب فارغ. لم يُرسل شيء.',
      );
    }
    if (!purposes.contains(purpose)) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'نوع التبادل غير معروف. لم يُرسل شيء.',
      );
    }
    if (from.profileId == to.profileId) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'لا تُرسل الوحدة الطلب إلى نفسها.',
      );
    }
    if (!accepts(to)) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'الجهة المستقبلة ليست وحدة علاجية. لم يُرسل شيء.',
      );
    }
    final fromPlace = UnitPlaceStamp.placeOf(from);
    final toPlace = UnitPlaceStamp.placeOf(to);
    double? km;
    if (fromPlace != null && toPlace != null) {
      km = NearbyCareFinder.distanceKm(
        fromLat: (fromPlace['latitude'] as num).toDouble(),
        fromLon: (fromPlace['longitude'] as num).toDouble(),
        toLat: (toPlace['latitude'] as num).toDouble(),
        toLon: (toPlace['longitude'] as num).toDouble(),
      );
    }
    final clock = at ?? DateTime.now();
    final id = 'UEX-${clock.microsecondsSinceEpoch}';
    final packet = <String, dynamic>{
      'id': id,
      'purpose': purpose,
      'text': body,
      'fromId': from.profileId,
      'toId': to.profileId,
      'fromSeat': from.billingSeat,
      'toSeat': to.billingSeat,
      'patientProfileId': patientProfileId.trim(),
      'fromLatitude': fromPlace?['latitude'],
      'fromLongitude': fromPlace?['longitude'],
      'toLatitude': toPlace?['latitude'],
      'toLongitude': toPlace?['longitude'],
      'fromAddress': _knownAddress(fromPlace),
      'toAddress': _knownAddress(toPlace),
      'distanceKm': km,
      'status': 'localSent',
      'resultNote': '',
      'serverDeliveryConfirmed': false,
      'createdAt': clock.toIso8601String(),
    };
    ProfileBoxStore(from).add(BoxKeys.unitExchange, packet);
    ProfileBoxStore(to).add(BoxKeys.unitExchange, packet);
    final distanceLine = km == null
        ? 'بلا مسافة لأن أحد الملفين بلا إحداثيات صادقة.'
        : 'المسافة التقريبية ${km.toStringAsFixed(1)} كم.';
    return UnitExchangeResult(
      ok: true,
      packetId: id,
      messageAr:
          'أُرسل نص الطلب فقط إلى الوحدة على هذا الجهاز. $distanceLine ليس تشخيصاً ولم يغادر الجهاز.',
    );
  }

  UnitExchangeResult answer({
    required HealthProfile unit,
    required List<HealthProfile> profiles,
    required String packetId,
    required String note,
  }) {
    final body = note.trim();
    if (body.isEmpty || packetId.trim().isEmpty) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'الرد فارغ. لم يُحفظ.',
      );
    }
    HealthProfile? sender;
    var found = false;
    for (final profile in profiles) {
      final items = ProfileBoxStore(profile).list(BoxKeys.unitExchange);
      final index = items.indexWhere((item) => item['id'] == packetId);
      if (index < 0) continue;
      final packet = items[index];
      if (packet['toId'] != unit.profileId) {
        return const UnitExchangeResult(
          ok: false,
          messageAr: 'الرد من الوحدة المستقبلة فقط. لم يُحفظ.',
        );
      }
      packet['status'] = 'answered';
      packet['resultNote'] = body;
      packet['serverDeliveryConfirmed'] = false;
      ProfileBoxStore(profile).setList(BoxKeys.unitExchange, items);
      found = true;
      if (packet['fromId'] == profile.profileId) sender = profile;
    }
    if (!found) {
      return const UnitExchangeResult(
        ok: false,
        messageAr: 'الطلب غير موجود في ملفات هذا الجهاز.',
      );
    }
    return UnitExchangeResult(
      ok: true,
      packetId: packetId,
      messageAr: sender == null
          ? 'حُفظ رد الوحدة على هذا الجهاز. ليس تفسيراً من Lifex.'
          : 'حُفظ رد الوحدة عند الطرفين على هذا الجهاز. ليس تفسيراً من Lifex.',
    );
  }
}
