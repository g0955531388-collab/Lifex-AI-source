/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: medical_reference_screen.dart
/// المسار: lib/screens/medical_reference_screen.dart
/// الوصف: مراجع من مشروع Android Studio المحلي: علامات الكاميرا،
/// الحالات، معايير الطول/الوزن، ودليل الأدوية. للتوعية فقط.
/// =============================================================
library lifex_ai.screens.medical_reference_screen;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/medical_record_canon.dart';
import '../core/reference_ledger.dart';
import '../widgets/encyclopedia_share_bar.dart';

enum MedicalReferenceKind { cameraSigns, conditions, growth, drugs }

class MedicalReferenceScreen extends StatefulWidget {
  const MedicalReferenceScreen({super.key, required this.kind});

  final MedicalReferenceKind kind;

  @override
  State<MedicalReferenceScreen> createState() => _MedicalReferenceScreenState();
}

class _MedicalReferenceScreenState extends State<MedicalReferenceScreen> {
  final _query = TextEditingController();
  List<_RefItem> _all = const [];
  bool _loading = true;
  String? _errorAr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = <_RefItem>[];
      for (final asset in _assetsFor(widget.kind)) {
        final raw = await rootBundle.loadString(asset);
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) continue;
            final row = Map<String, dynamic>.from(entry);
            if (!_belongs(asset, row)) continue;
            items.add(_RefItem.fromMap(row));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _all = _keepConflicts(items);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorAr = 'تعذّر تحميل المرجع. الملف موجود محلياً لكن القراءة فشلت.';
      });
    }
  }

  List<String> _assetsFor(MedicalReferenceKind kind) {
    switch (kind) {
      case MedicalReferenceKind.cameraSigns:
        return [
          'lib/data/reference/SmartCameraSigns.json',
          'lib/data/reference/face_sign_extras.json',
          'lib/data/reference/incoming_reference.json',
        ];
      case MedicalReferenceKind.conditions:
        return [
          'lib/data/reference/conditions_db_1000.json',
          'lib/data/reference/genital_conditions.json',
          'lib/data/reference/hands_conditions.json',
          'lib/data/reference/skin_hair_conditions.json',
          'lib/data/reference/incoming_reference.json',
        ];
      case MedicalReferenceKind.growth:
        return [
          'lib/data/reference/Height_Weight.json',
          'lib/data/reference/incoming_reference.json',
        ];
      case MedicalReferenceKind.drugs:
        return const [
          'lib/data/reference/drugs/Analgesics.json',
          'lib/data/reference/drugs/Antibiotics.json',
          'lib/data/reference/drugs/Antidiabetic.json',
          'lib/data/reference/drugs/Antifungal.json',
          'lib/data/reference/drugs/Antihypertensive.json',
          'lib/data/reference/drugs/AntiInflammatory.json',
          'lib/data/reference/drugs/Antipyretics.json',
          'lib/data/reference/drugs/Antiviral.json',
          'lib/data/reference/drugs/Cardiac.json',
          'lib/data/reference/drugs/Gastrointestinal.json',
          'lib/data/reference/drugs/MiscellaneousDrugs.json',
          'lib/data/reference/drugs/NeuroPsych.json',
          'lib/data/reference/drugs/Oncology.json',
          'lib/data/reference/drugs/PregnancySupplements.json',
          'lib/data/reference/drugs/Respiratory.json',
          'lib/data/reference/drugs/SexualHealth.json',
          'lib/data/reference/drugs/Vitamins.json',
          'lib/data/reference/incoming_reference.json',
        ];
    }
  }

  bool _belongs(String asset, Map<String, dynamic> row) {
    if (!asset.endsWith('incoming_reference.json')) return true;
    final kind = '${row['ledgerKind'] ?? ''}';
    return switch (widget.kind) {
      MedicalReferenceKind.cameraSigns => kind == 'علامة بصرية',
      MedicalReferenceKind.conditions => kind == 'حالة مرجعية',
      MedicalReferenceKind.growth => kind == 'معيار نمو',
      MedicalReferenceKind.drugs => kind == 'دواء مرجعي',
    };
  }

  String get _title {
    switch (widget.kind) {
      case MedicalReferenceKind.cameraSigns:
        return 'مرجع العلامات البصرية';
      case MedicalReferenceKind.conditions:
        return 'موسوعة الحالات';
      case MedicalReferenceKind.growth:
        return 'معايير الطول والوزن';
      case MedicalReferenceKind.drugs:
        return 'دليل الأدوية المرجعي';
    }
  }

  List<_RefItem> _keepConflicts(List<_RefItem> items) {
    final groups = <String, List<_RefItem>>{};
    for (final item in items) {
      final key = MedicalRecordCanon.normalize(item.title);
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(item);
    }
    final note = widget.kind == MedicalReferenceKind.drugs
        ? ReferenceLedger.doseNoteAr
        : ReferenceLedger.conflictNoteAr;
    final out = <_RefItem>[];
    for (final group in groups.values) {
      final bodies = group
          .map((item) => MedicalRecordCanon.normalize(item.subtitle))
          .where((text) => text.isNotEmpty)
          .toSet();
      if (bodies.length < 2) {
        group.sort((a, b) => b.subtitle.length.compareTo(a.subtitle.length));
        out.add(group.first);
        continue;
      }
      final seen = <String>{};
      for (final item in group) {
        final body = MedicalRecordCanon.normalize(item.subtitle);
        if (body.isEmpty || !seen.add(body)) continue;
        out.add(
          _RefItem(
            title: item.title,
            subtitle: '${item.subtitle} — $note',
          ),
        );
      }
    }
    return out;
  }

  List<_RefItem> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((item) =>
            item.title.toLowerCase().contains(q) ||
            item.subtitle.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      bottomNavigationBar: const EncyclopediaShareBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorAr != null
              ? Center(child: Text(_errorAr!))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'مرجع توعوي فقط. لا يشخص ولا يستبدل الطبيب. '
                        'العلامات البصرية لا تؤكد مرضاً من صورة واحدة.',
                        style: TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _query,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'بحث في ${_all.length} مدخلاً',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              title: Text(item.title),
                              subtitle: item.subtitle.isEmpty
                                  ? null
                                  : Text(item.subtitle),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RefItem {
  const _RefItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  factory _RefItem.fromMap(Map<String, dynamic> json) {
    if (json.containsKey('age_group')) {
      final male = json['male'] as Map<dynamic, dynamic>? ?? {};
      final female = json['female'] as Map<dynamic, dynamic>? ?? {};
      return _RefItem(
        title: json['age_group']?.toString() ?? '',
        subtitle:
            'ذكر: ${male['height_cm']} سم / ${male['weight_kg']} كغم — '
            'أنثى: ${female['height_cm']} سم / ${female['weight_kg']} كغم',
      );
    }
    final title = (json['name'] ??
            json['sign'] ??
            json['nameEn'] ??
            json['nameAr'] ??
            json['title'] ??
            '')
        .toString();
    final symptoms = json['symptoms'];
    final symptomText = symptoms is List ? symptoms.join('، ') : '';
    final subtitle = [
      json['meaning'],
      json['description'],
      json['area'],
      json['category'],
      symptomText,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' — ');
    return _RefItem(title: title, subtitle: subtitle);
  }
}
