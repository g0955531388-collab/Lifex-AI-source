/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: booking_workspace_screen.dart
/// الحجز الموحّد ورموز التحقق.
/// =============================================================
library lifex_ai.screens.booking_workspace_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/network_box/unified_booking_service.dart';
import '../features/profile/active_profile_controller.dart';
import '../services/cloud/cloud_sync_manager.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class BookingWorkspaceScreen extends StatelessWidget {
  const BookingWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const LifexText('الحجز والأكواد')),
            body: const Center(child: LifexText('لا يوجد ملف صحي نشط.')),
          );
        }
        final bookings = UnifiedBookingService(ProfileBoxStore(profile));
        final items = bookings.all();
        return Scaffold(
          appBar: AppBar(title: const LifexText('الحجز والأكواد')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context, controller, bookings),
            icon: const Icon(Icons.add),
            label: const LifexText('حجز محلي'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const HonestyBanner(
                messageAr:
                    'الحجز هنا مسودة على الجهاز. تأكيد الموعد لدى الطبيب أو المستشفى يحتاج خادماً. الرمز للعرض اليدوي وليس مسحاً آلياً.',
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const LifexText('لا حجوزات بعد.')
              else
                for (var i = 0; i < items.length; i++)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.qr_code_2)),
                      title: LifexText(items[i].title),
                      subtitle: LifexText(
                        '${items[i].unitId} — ${items[i].place}\n'
                        '${items[i].scheduledAt.year}/${items[i].scheduledAt.month}/${items[i].scheduledAt.day}\n'
                        'رمز: ${items[i].accessCode} — ${items[i].status}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: tr('حذف الحجز'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final profileId =
                              controller.activeProfileId ?? 'local';
                          final entry =
                              context.read<LioSensitiveActionEntry>();
                          final outcome = await entry.authorizeThenRun<void>(
                            request: LioGatewayRequest(
                              requestId:
                                  'booking_del_${i}_${DateTime.now().millisecondsSinceEpoch}',
                              correlationId: 'booking_$profileId',
                              identityAccountId: profileId,
                              purpose: 'scheduling',
                              requestedAction: 'delete_local_booking',
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
                              bookings.removeAt(i);
                            },
                          );
                          if (!outcome.executed) return;
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

  Future<void> _add(
    BuildContext context,
    ActiveProfileController controller,
    UnifiedBookingService bookings,
  ) async {
    final title = TextEditingController();
    final place = TextEditingController();
    var unitId = BoxUnitCatalog.hospital.id;
    var date = DateTime.now().add(const Duration(days: 1));
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const LifexText('حجز موحّد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: unitId,
                  items: BoxUnitCatalog.recordUnits
                      .where((unit) => unit.needsServer)
                      .map((unit) => DropdownMenuItem(
                            value: unit.id,
                            child: LifexText(unit.titleAr),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => unitId = value);
                  },
                  decoration: InputDecoration(labelText: tr('الوحدة')),
                ),
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: tr('الغرض')),
                ),
                TextField(
                  controller: place,
                  decoration: InputDecoration(labelText: tr('المكان')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const LifexText('التاريخ'),
                  subtitle: LifexText('${date.year}/${date.month}/${date.day}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const LifexText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const LifexText('حفظ'),
            ),
          ],
        ),
      ),
    );
    final heading = title.text.trim();
    final location = place.text.trim();
    title.dispose();
    place.dispose();
    if (saved != true || heading.isEmpty) return;
    final booking = bookings.add(
      unitId: unitId,
      title: heading,
      place: location.isEmpty ? 'غير محدد' : location,
      scheduledAt: date,
    );
    controller.saveActiveProfileChanges();
    if (!context.mounted) return;
    context.read<CloudSyncManager>().enqueue(
          entityType: SyncEntityType.appointment,
          entityId: booking.id,
          payload: booking.toJson(),
        );
  }
}
