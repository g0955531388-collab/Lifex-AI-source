import 'dart:convert';

class VaccineName {
  const VaccineName({required this.vaccineId, required this.names});

  final String vaccineId;
  final List<String> names;

  bool matches(String raw) {
    final needle = raw.trim().toLowerCase();
    if (needle.isEmpty) return false;
    for (final name in names) {
      final folded = name.trim().toLowerCase();
      if (folded.isEmpty) continue;
      if (needle == folded || needle.contains(folded)) return true;
    }
    return false;
  }
}

class VaccineNameIndex {
  const VaccineNameIndex(this.entries);

  static const bool dueCalculationAllowed = false;
  static const bool mandatoryFlagAllowed = false;
  static const bool dosingAdviceAllowed = false;
  static const bool earlyDoseAlertAllowed = false;

  final List<VaccineName> entries;

  factory VaccineNameIndex.fromJson(Map<String, dynamic> json) {
    final rows = (json['vaccines'] as List).cast<Map>();
    return VaccineNameIndex([
      for (final row in rows)
        VaccineName(
          vaccineId: '${row['vaccine_id']}',
          names: (row['names'] as List).map((name) => '$name').toList(),
        ),
    ]);
  }

  static VaccineNameIndex parse(String source) {
    return VaccineNameIndex.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  VaccineName? find(String name) {
    VaccineName? best;
    var bestLength = -1;
    for (final entry in entries) {
      if (!entry.matches(name)) continue;
      final length = entry.names.map((item) => item.length).reduce(
            (left, right) => left > right ? left : right,
          );
      if (length > bestLength) {
        best = entry;
        bestLength = length;
      }
    }
    return best;
  }

  List<VaccineName> matchRecorded(Iterable<String> recorded) {
    final found = <String, VaccineName>{};
    for (final line in recorded) {
      final hit = find(line);
      if (hit != null) found[hit.vaccineId] = hit;
    }
    return found.values.toList();
  }
}
