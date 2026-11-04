/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: camera_notes_screen.dart
/// التقاط أوراق بموافقة ظاهرة. OCR فارغ حتى محرك معتمد.
/// =============================================================
library lifex_ai.screens.camera_notes_screen;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/permission_transparency.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/cv_document_vault.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/record_management_actions.dart';
import 'layered_lens_studio_screen.dart';
import 'live_sight_screen.dart';
import 'medical_reference_screen.dart';
import 'thumbnail_manage_screen.dart';

class CameraNotesScreen extends StatefulWidget {
  const CameraNotesScreen({super.key});

  @override
  State<CameraNotesScreen> createState() => _CameraNotesScreenState();
}

class _CameraNotesScreenState extends State<CameraNotesScreen> {
  final _note = TextEditingController();
  String _kind = 'document';
  String _status = '';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _editNote(
    BuildContext context,
    ActiveProfileController controller,
    ProfileBoxStore store,
    Map<String, dynamic> note,
  ) async {
    final title = TextEditingController(text: note['title']?.toString() ?? '');
    final detail = TextEditingController(text: note['detail']?.toString() ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تعديل بيانات الملف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
                TextField(controller: detail, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      );
      if (saved != true || title.text.trim().isEmpty) return;
      final id = note['id']?.toString();
      if (id == null) return;
      store.updateById(BoxKeys.cameraNotes, id, {
        'title': title.text.trim(),
        'detail': detail.text.trim(),
      });
      controller.saveActiveProfileChanges();
      if (mounted) setState(() {});
    } finally {
      title.dispose();
      detail.dispose();
    }
  }

  Future<void> _capture() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إذن الكاميرا'),
        content: const Text(
          'لالتقاط أوراق أو شاشات أو منطقة جسم بموافقتك الظاهرة. لا تصوير خفي لمن يمسك الهاتف.',
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
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null || !mounted) return;
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    ProfileBoxStore(profile).add(BoxKeys.cameraNotes, {
      'title': _kind,
      'detail': _note.text.trim().isEmpty ? file.path : _note.text.trim(),
      'path': file.path,
    });
    CvDocumentVault(profile).attach(
      title: _kind,
      path: file.path,
      passphrase: profile.profileId,
      detail: _note.text.trim(),
    );
    controller.saveActiveProfileChanges();
    setState(() {
      _status =
          'حُفظ المسار. قراءة OCR الآلية فارغة حتى محرك معتمد. العلامات مرجع إشارات لا تشخيص.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    final controller = context.watch<ActiveProfileController>();
    final store = profile == null ? null : ProfileBoxStore(profile);
    final notes = store?.activeRecords(BoxKeys.cameraNotes) ?? const <Map<String, dynamic>>[];
    final archivedNotes = store?.archivedRecords(BoxKeys.cameraNotes) ?? const <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: const Text('الكاميرا الذكية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'أوراق وشاشات وعلامات كإشارات. ليست قراءة إشعاعية وليست تشخيص جلد.',
          ),
          DropdownButtonFormField<String>(
            value: _kind,
            items: const [
              DropdownMenuItem(value: 'document', child: Text('ورقة / وثيقة وطنية')),
              DropdownMenuItem(value: 'screen', child: Text('شاشة جهاز')),
              DropdownMenuItem(value: 'body', child: Text('منطقة جسم')),
              DropdownMenuItem(value: 'bedsore', child: Text('قرحة فراش')),
              DropdownMenuItem(value: 'tongue', child: Text('لسان')),
              DropdownMenuItem(value: 'skin', child: Text('جلد')),
              DropdownMenuItem(value: 'hair', child: Text('شعر')),
              DropdownMenuItem(value: 'vessel', child: Text('شرايين بارزة')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _kind = value);
            },
            decoration: const InputDecoration(labelText: 'نوع الالتقاط'),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
          ),
          FilledButton.icon(
            onPressed: _capture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('التقاط لقطة ثابتة بعد الموافقة'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              final id =
                  context.read<ActiveProfileController>().activeProfileId;
              if (id == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveSightScreen(profileId: id),
                ),
              );
            },
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('البث الحي على هذه الشاشة'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LayeredLensStudioScreen(),
                ),
              );
            },
            icon: const Icon(Icons.filter_none_outlined),
            label: const Text('عدسة الشرائح المتراكبة (جلد وتكبير)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThumbnailManageScreen(),
                ),
              );
            },
            icon: const Icon(Icons.image_outlined),
            label: const Text('Manage the thumbnail'),
          ),
          if (_status.isNotEmpty) Text(_status),
          for (final note in notes)
            ListTile(
              title: Text(note['title']?.toString() ?? ''),
              subtitle: Text(note['detail']?.toString() ?? ''),
              trailing: store == null
                  ? null
                  : RecordManagementActions(
                      onEdit: () => _editNote(context, controller, store, note),
                      onDelete: () async {
                        final id = note['id']?.toString();
                        if (id == null) return;
                        store.archiveById(BoxKeys.cameraNotes, id);
                        controller.saveActiveProfileChanges();
                        if (mounted) setState(() {});
                      },
                    ),
            ),
          if (archivedNotes.isNotEmpty) ...[
            const Divider(),
            const Text('الأرشيف — ملفات محفوظة لإعادة الفتح'),
            for (final note in archivedNotes)
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(note['title']?.toString() ?? ''),
                subtitle: Text(note['detail']?.toString() ?? ''),
                trailing: TextButton(
                  onPressed: () {
                    final id = note['id']?.toString();
                    if (id == null || store == null) return;
                    store.restoreArchivedById(BoxKeys.cameraNotes, id);
                    controller.saveActiveProfileChanges();
                    setState(() {});
                  },
                  child: const Text('إعادة فتح'),
                ),
              ),
          ],
          ListTile(
            title: const Text('مرجع العلامات البصرية'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MedicalReferenceScreen(
                  kind: MedicalReferenceKind.cameraSigns,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
