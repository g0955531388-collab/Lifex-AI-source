/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: unit_branch_records_screen.dart
/// سجلات متفرعة لحقل واحد داخل وحدة، مع حقول إضافية من السيناريو.
/// =============================================================
library lifex_ai.screens.unit_branch_records_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/network_box/profile_box_store.dart';
import '../features/network_box/unit_branch_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/record_management_actions.dart';

class UnitBranchRecordsScreen extends StatelessWidget {
  const UnitBranchRecordsScreen({super.key, required this.branch});

  final UnitBranch branch;

  @override
  Widget build(BuildContext context) {
    final storageKey = branch.storageKey;
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null || storageKey == null) {
          return Scaffold(
            appBar: AppBar(title: Text(branch.titleAr)),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final records = store.activeRecords(storageKey);
        return Scaffold(
          appBar: AppBar(title: Text(branch.titleAr)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context, controller, store, storageKey),
            icon: const Icon(Icons.add),
            label: const Text('إضافة'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(branch.subtitleAr,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              HonestyBanner.localAndServer(),
              HonestyBanner.medical(),
              if (branch.needsServer) const SizedBox(height: 8),
              if (branch.needsServer)
                const HonestyBanner(
                  messageAr:
                      'هذا الفرع ينتظر حساب جهة وخادماً للتأكيد الخارجي. ما يُحفظ هنا مسودة على الجهاز.',
                ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const Text('لا توجد سجلات في هذا الفرع بعد.')
              else
                for (var i = 0; i < records.length; i++)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(branch.icon)),
                      title: Text(records[i]['title']?.toString() ?? ''),
                      subtitle: Text(_subtitle(records[i])),
                      isThreeLine: _subtitle(records[i]).contains('\n'),
                      trailing: RecordManagementActions(
                        onEdit: () => _add(
                          context,
                          controller,
                          store,
                          storageKey,
                          existing: records[i],
                        ),
                        onDelete: () async {
                          final id = records[i]['id']?.toString();
                          if (id == null) return;
                          store.archiveById(storageKey, id);
                          controller.saveActiveProfileChanges();
                        },
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(Map<String, dynamic> record) {
    final lines = <String>[
      record['detail']?.toString() ?? '',
    ];
    for (final field in branch.extraFields) {
      final value = record[field.key]?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      lines.add('${field.labelAr}: $value');
    }
    return lines.where((line) => line.isNotEmpty).join('\n');
  }

  Future<void> _add(
    BuildContext context,
    ActiveProfileController controller,
    ProfileBoxStore store,
    String storageKey, {
    Map<String, dynamic>? existing,
  }) async {
    final title = TextEditingController(text: existing?['title']?.toString() ?? '');
    final detail = TextEditingController(text: existing?['detail']?.toString() ?? '');
    final extras = {
      for (final field in branch.extraFields)
        field.key: TextEditingController(text: existing?[field.key]?.toString() ?? ''),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? branch.titleAr : 'تعديل ${branch.titleAr}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: InputDecoration(labelText: branch.primaryLabelAr),
              ),
              TextField(
                controller: detail,
                maxLines: 3,
                decoration: InputDecoration(labelText: branch.detailLabelAr),
              ),
              for (final field in branch.extraFields)
                TextField(
                  controller: extras[field.key],
                  maxLines: field.maxLines,
                  decoration: InputDecoration(labelText: field.labelAr),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final heading = title.text.trim();
    final note = detail.text.trim();
    final extraValues = {
      for (final field in branch.extraFields)
        field.key: extras[field.key]?.text.trim() ?? '',
    };
    title.dispose();
    detail.dispose();
    for (final controller in extras.values) {
      controller.dispose();
    }
    if (saved != true || heading.isEmpty) return;
    final values = {
      'title': heading,
      'detail': note.isEmpty ? 'بدون تفاصيل' : note,
      ...extraValues,
    };
    if (existing == null) {
      store.add(storageKey, values);
    } else {
      final id = existing['id']?.toString();
      if (id == null || !store.updateById(storageKey, id, values)) return;
    }
    controller.saveActiveProfileChanges();
  }
}
