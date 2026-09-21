/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: emergency_contacts_screen.dart
/// المسار: lib/screens/emergency_contacts_screen.dart
/// الوصف: إدارة جهات الثقة للطوارئ داخل الملف الصحي المحلي.
/// =============================================================
library lifex_ai.screens.emergency_contacts_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/emergency/emergency_phone_contacts_registry.dart';
import '../features/profile/active_profile_controller.dart';

enum _ContactLevel { notifyOnly, monitoring, delegate }

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    final raw = context
        .read<ActiveProfileController>()
        .activeProfile
        ?.questionnaireData['trustedContacts'];
    if (raw is List) {
      _contacts = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRegistry();
    });
  }

  void _syncRegistry() {
    final profileId =
        context.read<ActiveProfileController>().activeProfileId;
    if (profileId == null) return;
    context.read<EmergencyPhoneContactsRegistry>().replaceForProfile(
          profileId,
          _contacts.map((c) => c['phone']?.toString() ?? ''),
        );
  }

  void _persist() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    profile.questionnaireData['trustedContacts'] = _contacts;
    profile.lastUpdatedAt = DateTime.now();
    controller.saveActiveProfileChanges();
    _syncRegistry();
  }

  Future<void> _add() async {
    if (_contacts.length >= maxEmergencyPhoneContactsPerProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الحد الأقصى 10 أرقام موثوقة للطوارئ.'),
        ),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (result == null) return;
    if (!mounted) return;
    final phone = result['phone']?.toString().trim() ?? '';
    final profileId =
        context.read<ActiveProfileController>().activeProfileId;
    if (phone.isNotEmpty && profileId != null) {
      final registry = context.read<EmergencyPhoneContactsRegistry>();
      final added = registry.addContact(profileId: profileId, phoneNumber: phone);
      if (!added.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(added.messageAr)),
        );
        return;
      }
    }
    setState(() => _contacts.add(result));
    _persist();
  }

  String _levelLabel(String? value) {
    switch (value) {
      case 'monitoring':
        return 'مراقبة صحية';
      case 'delegate':
        return 'مفوّض كامل';
      default:
        return 'إشعار طوارئ فقط';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جهات الثقة للطوارئ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة جهة'),
      ),
      body: _contacts.isEmpty
          ? const Center(child: Text('لم تتم إضافة جهات ثقة بعد.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.verified_user_outlined)),
                    title: Text(contact['name']?.toString() ?? ''),
                    subtitle: Text(
                        '${contact['phone'] ?? contact['lifexId']} — ${_levelLabel(contact['level']?.toString())}'),
                    trailing: IconButton(
                      tooltip: 'حذف جهة الثقة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final profileId = context
                                .read<ActiveProfileController>()
                                .activeProfileId ??
                            'local';
                        final entry =
                            context.read<LioSensitiveActionEntry>();
                        final outcome = await entry.authorizeThenRun<void>(
                          request: LioGatewayRequest(
                            requestId:
                                'emg_contact_del_${index}_${DateTime.now().millisecondsSinceEpoch}',
                            correlationId: 'emg_$profileId',
                            identityAccountId: profileId,
                            purpose: 'emergency_signal',
                            requestedAction: 'delete_emergency_contact',
                            dataScope: 'emergency_contacts_min',
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
                            _contacts.removeAt(index);
                          },
                        );
                        if (!outcome.executed || !mounted) return;
                        setState(() {});
                        _persist();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _name = TextEditingController();
  final _lifexId = TextEditingController();
  final _phone = TextEditingController();
  _ContactLevel _level = _ContactLevel.notifyOnly;

  @override
  void dispose() {
    _name.dispose();
    _lifexId.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة جهة ثقة'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الجهة')),
          TextField(
              controller: _lifexId,
              decoration:
                  const InputDecoration(labelText: 'Lifex-ID أو المعرّف')),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'رقم الهاتف الموثوق (حتى 10 أرقام)')),
          DropdownButtonFormField<_ContactLevel>(
            value: _level,
            decoration: const InputDecoration(labelText: 'الصلاحية'),
            items: const [
              DropdownMenuItem(
                  value: _ContactLevel.notifyOnly,
                  child: Text('إشعار طوارئ فقط')),
              DropdownMenuItem(
                  value: _ContactLevel.monitoring, child: Text('مراقبة صحية')),
              DropdownMenuItem(
                  value: _ContactLevel.delegate, child: Text('مفوّض كامل')),
            ],
            onChanged: (value) =>
                setState(() => _level = value ?? _ContactLevel.notifyOnly),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty ||
                (_lifexId.text.trim().isEmpty && _phone.text.trim().isEmpty)) {
              return;
            }
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'lifexId': _lifexId.text.trim(),
              'phone': _phone.text.trim(),
              'level': _level.name,
            });
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
