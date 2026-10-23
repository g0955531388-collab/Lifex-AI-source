/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: camera_notes_screen.dart
/// التقاط أوراق بموافقة ظاهرة. OCR فارغ حتى محرك معتمد.
/// =============================================================
library lifex_ai.screens.camera_notes_screen;

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/permission_transparency.dart';
import '../features/accessibility/blind_camera_speech.dart';
import '../features/accessibility/file_path_image_labeler.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/cv_document_vault.dart';
import '../features/vision/document_capture_reading.dart';
import '../features/vision/file_path_ocr_extractor.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
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
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      await _say('رُفض إذن الكاميرا. الالتقاط متوقف.');
      return;
    }
    final file = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => const _LensShotPage()),
    );
    if (!mounted) return;
    if (file == null) {
      await _say('أُغلقت العدسة قبل الالتقاط. لم تُحفظ صورة.');
      return;
    }
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) {
      await _say('أنشئ الملف الصحي أولاً. الصورة لم تُحفظ في الأرشيف.');
      return;
    }
    final userNote = _note.text.trim();
    final labels =
        await const FilePathImageLabeler().labelsFromPath(file.path);
    final scene = BlindCameraSpeech.sceneFromLabels(labels);
    var reading = '';
    if (_kind == 'document') {
      final raw = await const FilePathOcrExtractor().extractFromPath(file.path);
      reading = DocumentCaptureReading.compose(raw).storedAr;
    }
    final detail = [
      if (userNote.isNotEmpty) userNote,
      scene,
      if (reading.isNotEmpty) reading,
    ].join('\n');
    ProfileBoxStore(profile).add(BoxKeys.cameraNotes, {
      'title': _kind,
      'detail': detail,
      'path': file.path,
    });
    CvDocumentVault(profile).attach(
      title: _kind,
      path: file.path,
      passphrase: profile.profileId,
      detail: detail,
    );
    controller.saveActiveProfileChanges();
    final status = [
      scene,
      if (reading.isNotEmpty) reading,
    ].join('\n');
    await _say(status);
  }

  Future<void> _say(String text) async {
    if (!mounted) return;
    setState(() => _status = text);
    await VoiceEngine.instance.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    final notes = profile == null
        ? const <Map<String, dynamic>>[]
        : ProfileBoxStore(profile).list(BoxKeys.cameraNotes);
    return Scaffold(
      appBar: AppBar(title: const Text('الكاميرا الذكية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'أوراق وشاشات وعلامات كإشارات. ليست قراءة إشعاعية وليست تشخيص جلد. '
                'قارئ النص المثبت يقرأ الحرف اللاتيني المطبوع. العربية والخط اليدوي غير مدعومين في هذا المحرك، والنص الناقص لا يُكمَّل بالتخمين.',
          ),
          FilledButton.icon(
            onPressed: () {
              final id =
                  context.read<ActiveProfileController>().activeProfileId;
              if (id == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveSightScreen(
                    profileId: id,
                    ask: BlindCameraAsk.scene,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('كاميرا المكفوفين'),
          ),
          const SizedBox(height: 8),
          const Text(
            'البث الحي يقرأ إطارات العدسة. كاشف الصناديق غير محمّل، فتصنيف الصورة ليس كشف أجسام ولا يقدّر مسافة.',
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
            label: const Text('افتح العدسة والتقط'),
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
            label: const Text('تقريب العدسة'),
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
            label: const Text('مصغّرات الأوراق'),
          ),
          if (_status.isNotEmpty) Text(_status),
          for (final note in notes)
            ListTile(
              title: Text(note['title']?.toString() ?? ''),
              subtitle: Text(note['detail']?.toString() ?? ''),
            ),
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

class _LensShotPage extends StatefulWidget {
  const _LensShotPage();

  @override
  State<_LensShotPage> createState() => _LensShotPageState();
}

class _LensShotPageState extends State<_LensShotPage> {
  CameraController? _lens;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    final lens = _lens;
    _lens = null;
    if (lens != null) unawaited(lens.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final found = await availableCameras();
      if (!mounted) return;
      if (found.isEmpty) {
        setState(() => _error = 'لا توجد عدسة ظاهرة على هذا الجهاز.');
        return;
      }
      final rear = found.where(
        (item) => item.lensDirection == CameraLensDirection.back,
      );
      final chosen = rear.isEmpty ? found.first : rear.first;
      final lens = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await lens.initialize();
      if (!mounted) {
        await lens.dispose();
        return;
      }
      setState(() => _lens = lens);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر فتح العدسة. $error');
    }
  }

  Future<void> _shoot() async {
    final lens = _lens;
    if (_busy || lens == null || !lens.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final shot = await lens.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(shot);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر حفظ اللقطة. $error';
      });
    }
  }

  bool get _lensReady {
    final lens = _lens;
    return lens != null && lens.value.isInitialized;
  }

  Widget _preview() {
    final lens = _lens;
    if (lens != null && lens.value.isInitialized) {
      final ratio =
          lens.value.aspectRatio == 0 ? 3 / 4 : lens.value.aspectRatio;
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: ratio,
          child: CameraPreview(lens),
        ),
      );
    }
    if (_error == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عدسة الالتقاط')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
          _preview(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _lensReady && !_busy ? _shoot : null,
            child: const Text('التقط واحفظ'),
          ),
        ],
      ),
    );
  }
}
