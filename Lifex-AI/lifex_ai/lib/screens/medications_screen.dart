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

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
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
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.readMedicalBundle(
      gatewayRequest: LioGatewayRequest(
        requestId: 'med_catalog_${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}',
        correlationId: 'med_${widget.profileId}',
        identityAccountId: widget.profileId,
        purpose: 'knowledge_lookup',
        requestedAction: 'read_medical_catalog',
        dataScope: 'knowledge_public',
        sensitivity: LioDataSensitivity.public,
        consent: const LioConsentContext(
          consentGranted: true,
          purposeAligned: true,
        ),
        riskLevel: LioActionRisk.low,
        timestamp: DateTime.now().toUtc(),
        authenticated: true,
        authorized: true,
        minimumNecessarySatisfied: true,
      ),
      fileName: MedicalBundleFiles.medications,
    );
    if (!mounted) return;
    if (!outcome.executed) {
      setState(() {
        _catalog = const [];
        _loading = false;
      });
      return;
    }
    final json = outcome.value ?? const <String, dynamic>{};
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

  Future<void> _addMedication(HealthProfile profile) async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة دواء إلى السجل الشخصي'),
        content: TextField(
          controller: controller,
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
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (added != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    if (!profile.currentMedicationNames.contains(name)) {
      profile.currentMedicationNames.add(name);
      profile.lastUpdatedAt = DateTime.now();
    }
    if (!mounted) return;
    setState(() {});
    Provider.of<ActiveProfileController>(context, listen: false)
        .notifyProfileChanged();
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
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final entry =
                                        Provider.of<LioSensitiveActionEntry>(
                                      context,
                                      listen: false,
                                    );
                                    final outcome =
                                        await entry.authorizeThenRun<void>(
                                      request: LioGatewayRequest(
                                        requestId:
                                            'med_del_${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}',
                                        correlationId: 'med_${widget.profileId}',
                                        identityAccountId: widget.profileId,
                                        purpose: 'care_support',
                                        requestedAction:
                                            'delete_local_medication_name',
                                        dataScope: 'profile_basic',
                                        sensitivity: LioDataSensitivity.personal,
                                        consent: const LioConsentContext(
                                          consentGranted: true,
                                          purposeAligned: true,
                                        ),
                                        riskLevel: LioActionRisk.medium,
                                        timestamp: DateTime.now().toUtc(),
                                        authenticated: true,
                                        authorized: true,
                                        minimumNecessarySatisfied: true,
                                      ),
                                      run: () async {
                                        profile.currentMedicationNames
                                            .remove(name);
                                      },
                                    );
                                    if (!outcome.executed || !mounted) return;
                                    Provider.of<ActiveProfileController>(
                                      context,
                                      listen: false,
                                    ).notifyProfileChanged();
                                    setState(() {});
                                  },
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
