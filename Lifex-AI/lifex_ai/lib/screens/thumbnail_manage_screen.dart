/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: thumbnail_manage_screen.dart
/// Manage the thumbnail: ختم رسمي أو صورة ملف، ومصغّرات أوراق الكاميرا.
/// =============================================================
library lifex_ai.screens.thumbnail_manage_screen;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/permission_transparency.dart';
import '../features/identity/thumbnail_ledger.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_thumbnail.dart';

class ThumbnailManageScreen extends StatefulWidget {
  const ThumbnailManageScreen({super.key});

  @override
  State<ThumbnailManageScreen> createState() => _ThumbnailManageScreenState();
}

class _ThumbnailManageScreenState extends State<ThumbnailManageScreen> {
  String _status = '';

  Future<void> _pick(ImageSource source) async {
    if (source == ImageSource.camera) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('صورة مصغّرة للملف'),
          content: const Text(
            'لقطة ظاهرة لصاحب هذا الملف فقط. ليست تصويراً خفياً، '
            'ولا تُرفع لمتجر أو خادم من هذه الشاشة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رفض'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      PermissionTransparencyManager.instance.decide(
        permission: LifexSensitivePermission.camera,
        granted: true,
      );
    }
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    ThumbnailLedger(ProfileBoxStore(profile)).setCustomPath(file.path);
    controller.saveActiveProfileChanges();
    setState(() => _status = 'حُفظت الصورة المصغّرة على هذا الجهاز.');
  }

  void _restoreSeal() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    ThumbnailLedger(ProfileBoxStore(profile)).restoreOfficialSeal();
    controller.saveActiveProfileChanges();
    setState(() => _status = 'عادت الصورة المصغّرة إلى الختم الرسمي.');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Manage the thumbnail')),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final ledger = ThumbnailLedger(store);
        final notes = store.list(BoxKeys.cameraNotes);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage the thumbnail'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'إدارة الصورة المصغّرة',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const HonestyBanner(
                messageAr:
                    'هذه صورة الملف داخل التطبيق. أيقونة المتجر والشاشة الرئيسية للنظام تبقى ختم Lifex-AI عند بناء التطبيق. البث الحي لا يمرّ من هنا ولا يُحفظ إطار.',
              ),
              const SizedBox(height: 16),
              Center(
                child: LifexThumbnail(
                  localPath: ledger.customPath,
                  size: 168,
                ),
              ),
              const SizedBox(height: 12),
              Text(ledger.statusAr(), textAlign: TextAlign.center),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_status, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('اختيار من المعرض'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('التقاط صورة ظاهرة'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: ledger.usesOfficialSeal ? null : _restoreSeal,
                child: const Text('استعادة الختم الرسمي'),
              ),
              const SizedBox(height: 24),
              Text(
                'مصغّرات أوراق الكاميرا',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (notes.isEmpty)
                const Text('لا أوراق مصوّرة بعد. التقط من الكاميرا الذكية.')
              else
                for (var i = 0; i < notes.length; i++)
                  Card(
                    child: ListTile(
                      leading: _noteThumb(notes[i]['path']?.toString()),
                      title: Text(notes[i]['title']?.toString() ?? 'ورقة'),
                      subtitle: Text(notes[i]['detail']?.toString() ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final profileId =
                              controller.activeProfileId ?? 'local';
                          final entry =
                              context.read<LioSensitiveActionEntry>();
                          final outcome = await entry.authorizeThenRun<void>(
                            request: LioGatewayRequest(
                              requestId:
                                  'thumb_del_${i}_${DateTime.now().millisecondsSinceEpoch}',
                              correlationId: 'thumb_$profileId',
                              identityAccountId: profileId,
                              purpose: 'settings',
                              requestedAction: 'delete_camera_note_thumbnail',
                              dataScope: 'settings_local',
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
                              store.removeAt(BoxKeys.cameraNotes, i);
                            },
                          );
                          if (!outcome.executed || !mounted) return;
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

  Widget _noteThumb(String? path) {
    if (path == null || path.isEmpty || kIsWeb) {
      return const CircleAvatar(child: Icon(Icons.image_outlined));
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const CircleAvatar(child: Icon(Icons.broken_image_outlined));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover),
    );
  }
}
