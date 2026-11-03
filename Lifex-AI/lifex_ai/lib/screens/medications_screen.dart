/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: medications_screen.dart
/// المسار: lib/screens/medications_screen.dart
/// الوصف: سجل الأدوية الشخصي فوق Medication Profile في الملف الصحي،
/// مع مرجع من medications_database.json وتنبيه تداخلات معروف. لا يصف
/// دواء ولا يحدد جرعة — تنفيذ بند الوثيقة الموحّدة ودردشة 14 أيلول.
/// =============================================================
library lifex_ai.screens.medications_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/medical_database_manager.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import 'medication_alarm_screen.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Map<String, dynamic>> _catalog = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final manager =
        Provider.of<MedicalDatabaseManager>(context, listen: false);
    final json = await manager.readBundleFile(MedicalBundleFiles.medications);
    if (!mounted) return;
    setState(() {
      _catalog = (json['medications'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _loading = false;
    });
  }

  Map<String, dynamic>? _matchCatalog(String name) {
    final needle = name.trim().toLowerCase();
    for (final item in _catalog) {
      final ar = (item['nameAr'] as String? ?? '').toLowerCase();
      final en = (item['nameEn'] as String? ?? '').toLowerCase();
      if (ar == needle || en.contains(needle) || needle.contains(ar)) {
        return item;
      }
    }
    return null;
  }

  List<String> _interactionWarnings(HealthProfile profile) {
    final warnings = <String>[];
    final matched = <Map<String, dynamic>>[];
    for (final name in profile.currentMedicationNames) {
      final item = _matchCatalog(name);
      if (item != null) matched.add(item);
    }
    for (final item in matched) {
      final ids = (item['knownInteractionsWithIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      for (final other in matched) {
        if (item['id'] == other['id']) continue;
        if (ids.contains(other['id'])) {
          warnings.add(
            'تنبيه تداخل مرجعي: ${item['nameAr']} مع ${other['nameAr']}. '
            'راجع طبيبك قبل أي تغيير.',
          );
        }
      }
    }
    for (final name in profile.currentMedicationNames) {
      if (profile.hasAllergyTo(name)) {
        warnings.add(
          'هذا الاسم يظهر في سجل الحساسية: $name. لا تتناوله قبل مراجعة الطبيب.',
        );
      }
    }
    return warnings.toSet().toList();
  }

  Future<void> _editMedication(
    HealthProfile profile,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تعديل اسم الدواء في السجل'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'اسم الدواء كما وصفه الطبيب',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      final updatedName = controller.text.trim();
      if (saved != true || updatedName.isEmpty || updatedName == currentName) return;
      final index = profile.currentMedicationNames.indexOf(currentName);
      if (index < 0) return;
      if (profile.currentMedicationNames.contains(updatedName)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الدواء موجود بالفعل في السجل.')),
        );
        return;
      }
      profile.currentMedicationNames[index] = updatedName;
      profile.lastUpdatedAt = DateTime.now();
      if (!mounted) return;
      final profiles = Provider.of<ActiveProfileController>(context, listen: false);
      profiles.notifyProfileChanged();
      setState(() {});
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, profiles, _) {
        final profile = profiles.profileById(widget.profileId);
        return Scaffold(
          appBar: AppBar(
            title: const Text('أدويتي'),
            actions: [
              IconButton(
                tooltip: 'منبّه الأدوية الذكي',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MedicationAlarmScreen(),
                  ),
                ),
                icon: const Icon(Icons.alarm),
              ),
            ],
          ),
          floatingActionButton: profile == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _addMedication(profile),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة دواء'),
                ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : profile == null
                  ? const Center(child: Text('لا يوجد ملف صحي نشط.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      children: [
                        const Text(
                          'هذه شاشة سجل شخصي وتوعية فقط. Lifex-AI لا يصف '
                          'دواء ولا يحدّد جرعة. اتبع وصفة الطبيب ونشرة الدواء.',
                          style: TextStyle(fontSize: 13, color: Colors.orange),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MedicationAlarmScreen(),
                            ),
                          ),
                          child: const Text('منبّه الأدوية الذكي لكل أفراد الحساب'),
                        ),
                        for (final warning in _interactionWarnings(profile))
                          Card(
                            color: Colors.red.withOpacity(0.08),
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_outlined),
                              title: Text(warning),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'سجل أدويتي',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (profile.currentMedicationNames.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('لم تُضف أي أدوية بعد.'),
                          )
                        else
                          for (final name in profile.currentMedicationNames)
                            Card(
                              child: ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  _matchCatalog(name)?['generalNoteAr']
                                          as String? ??
                                      'غير موجود في المرجع العام؛ يبقى في سجلك كما كتبته.',
                                ),
                                trailing: IconButton(
                                  tooltip: 'تعديل بيانات الدواء',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editMedication(profile, name),
                                ),
                              ),
                            ),
                        const SizedBox(height: 16),
                        Text(
                          'مرجع عام من قاعدة الأدوية',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final item in _catalog)
                          ListTile(
                            title: Text(item['nameAr'] as String? ?? ''),
                            subtitle: Text(
                              '${item['category'] ?? ''} — '
                              '${item['requiresPrescription'] == true ? "يحتاج وصفة" : "مرجع عام"}',
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}
