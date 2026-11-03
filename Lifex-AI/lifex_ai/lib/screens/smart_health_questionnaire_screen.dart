/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: smart_health_questionnaire_screen.dart
/// اثنا عشر قسماً تُحفظ في الملف الصحي. قراءة صوتية للقسم الحالي.
/// الصور عبر أرشيف الأوراق بعد موافقة. ليس تشخيصاً.
/// =============================================================
library lifex_ai.screens.smart_health_questionnaire_screen;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/license_manager.dart';
import '../core/permission_transparency.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/cv_document_vault.dart';
import '../features/profile/health_profile.dart';
import '../features/profile/health_questionnaire_schema.dart';
import '../features/profile/html_survey_alias.dart';
import '../features/profile/questionnaire_consistency.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/voice_fill_button.dart';
import 'camera_notes_screen.dart';
import 'stamped_reports_screen.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class SmartHealthQuestionnaireScreen extends StatefulWidget {
  const SmartHealthQuestionnaireScreen({super.key});

  @override
  State<SmartHealthQuestionnaireScreen> createState() =>
      _SmartHealthQuestionnaireScreenState();
}

class _SmartHealthQuestionnaireScreenState
    extends State<SmartHealthQuestionnaireScreen> {
  final Map<String, dynamic> _answers = <String, dynamic>{};
  final Map<String, TextEditingController> _textControllers = {};
  int _section = 0;
  String? _consistencyAr;
  bool _speakOnFocus = true;
  bool _welcomed = false;

  static const _sections = HealthQuestionnaireSchema.sections;

  @override
  void initState() {
    super.initState();
    final existing = context
        .read<ActiveProfileController>()
        .activeProfile
        ?.questionnaireData;
    if (existing != null) {
      _answers.addAll(HtmlSurveyAlias.foldIntoCanon(
        Map<String, dynamic>.from(existing),
      ));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _welcomed) return;
      _welcomed = true;
      VoiceEngine.instance.speak(
        LicenseManager.instance.appendAr(
          'مرحباً في صفحة صاحب الحساب. املأ بلغتك صوتاً أو كتابة. '
          'الصور اختيارية عبر الكاميرا الذكية. التقرير المختوم بعد الحفظ. ليست تشخيصاً.',
        ),
      );
    });
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(QuestionField question) {
    return _textControllers.putIfAbsent(
      question.key,
      () => TextEditingController(
          text: (_answers[question.key] ?? '').toString()),
    );
  }

  void _flushControllers() {
    for (final entry in _textControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        _answers.remove(entry.key);
      } else {
        _answers[entry.key] = value;
      }
    }
  }

  void _save() {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return;
    _flushControllers();
    _applyCoreFields(profile);
    profile.questionnaireData = Map<String, dynamic>.from(_answers);
    profile.lastUpdatedAt = DateTime.now();
    context.read<ActiveProfileController>().saveActiveProfileChanges();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: LifexText('تم حفظ الاستبيان الصحي في ملفك.')),
    );
    VoiceEngine.instance.speak(
      'تم حفظ إجاباتك في ملفك على هذا الجهاز. ليست معالجة سحابية ولا تقريراً طبياً.',
    );
  }

  Future<void> _capturePhoto(QuestionField question) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const LifexText('إذن الكاميرا'),
        content: LifexText('التقاط ${question.label} بموافقتك. ليست قراءة تامة للصورة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const LifexText('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const LifexText('موافق'),
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
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return;
    setState(() => _answers[question.key] = file.path);
    CvDocumentVault(profile).attach(
      title: question.key,
      path: file.path,
      passphrase: profile.profileId,
      detail: question.label,
    );
    context.read<ActiveProfileController>().saveActiveProfileChanges();
  }

  void _applyCoreFields(HealthProfile profile) {
    final weight = double.tryParse(_answers['weightKg']?.toString() ?? '');
    final height = double.tryParse(_answers['heightCm']?.toString() ?? '');
    if (weight != null && weight > 0) profile.weightKg = weight;
    if (height != null && height > 0) profile.heightCm = height;

    final sex = _answers['surveySex']?.toString();
    if (sex == 'ذكر') profile.biologicalSex = BiologicalSex.male;
    if (sex == 'أنثى') profile.biologicalSex = BiologicalSex.female;

    final mapped = _bloodFromLabel(_answers['surveyBloodType']?.toString());
    if (mapped != null) profile.bloodType = mapped;

    final phone = _answers['surveyPhone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) {
      _answers['accountPhone'] = phone;
    }

    final allergyText = _answers['allergyList']?.toString().trim() ?? '';
    if (allergyText.isNotEmpty) {
      for (final token in allergyText.split(RegExp(r'[،,]+'))) {
        final substance = token.trim();
        if (substance.isEmpty || profile.hasAllergyTo(substance)) continue;
        profile.addAllergy(
          AllergyRecord(substance: substance, severity: 'medium'),
        );
      }
    }

    final medicationText = _answers['medicationList']?.toString().trim() ?? '';
    if (medicationText.isNotEmpty) {
      for (final token in medicationText.split(RegExp(r'[،,\n]+'))) {
        final name = token.trim();
        if (name.isEmpty || profile.currentMedicationNames.contains(name)) {
          continue;
        }
        profile.currentMedicationNames.add(name);
      }
    }
  }

  BloodType? _bloodFromLabel(String? label) {
    switch (label) {
      case 'A+':
        return BloodType.aPositive;
      case 'A-':
        return BloodType.aNegative;
      case 'B+':
        return BloodType.bPositive;
      case 'B-':
        return BloodType.bNegative;
      case 'AB+':
        return BloodType.abPositive;
      case 'AB-':
        return BloodType.abNegative;
      case 'O+':
        return BloodType.oPositive;
      case 'O-':
        return BloodType.oNegative;
      default:
        return null;
    }
  }

  Future<void> _speakSection() async {
    await VoiceEngine.instance.speak(
      LicenseManager.instance.appendAr(_sections[_section].spokenOutline),
    );
  }

  void _maybeSpeakField(String label) {
    if (!_speakOnFocus) return;
    VoiceEngine.instance.speak('يرجى إدخال $label');
  }

  void _showConsistency() {
    _flushControllers();
    final profile = context.read<ActiveProfileController>().activeProfile;
    final notes = QuestionnaireConsistency.notes(
      _answers,
      sex: profile?.biologicalSex,
    );
    setState(() {
      _consistencyAr = notes.isEmpty
          ? 'لا تعارض إدخال واضح وفق القواعد الحالية. هذا ليس تشخيصاً.'
          : notes.map((line) => '• $line').join('\n');
    });
  }

  void _showSummary() {
    _flushControllers();
    final text = QuestionnaireConsistency.summary(_answers);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LifexText('ملخص إدخالك'),
        content: SingleChildScrollView(child: LifexText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LifexText('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyJson() async {
    _flushControllers();
    final payload = {
      for (final key in HealthQuestionnaireSchema.allKeys())
        if (_answers[key] != null) key: _answers[key],
    };
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: LifexText('نُسخ JSON الاستبيان إلى الحافظة. ليس تقريراً طبياً.')),
    );
  }

  Future<void> _copyPlainText() async {
    _flushControllers();
    final buf = StringBuffer('الاستبيان الصحي — إدخال محلي وليس تقريراً طبياً\n');
    for (final section in _sections) {
      buf.writeln('\n${section.title}');
      for (final field in section.fields) {
        final value = _answers[field.key];
        if (value == null || value.toString().trim().isEmpty) continue;
        buf.writeln('${field.label}: $value');
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: LifexText('نُسخ نص الأقسام إلى الحافظة.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _sections[_section];
    final progress = (_section + 1) / _sections.length;
    return Scaffold(
      appBar: AppBar(
        title: const LifexText('الاستبيان الصحي الناطق'),
        actions: [
          IconButton(
            tooltip: tr('قراءة هذا القسم'),
            onPressed: _speakSection,
            icon: const Icon(Icons.volume_up_outlined),
          ),
          IconButton(
            tooltip: tr('أوراق وتقارير مصوّرة'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraNotesScreen()),
            ),
            icon: const Icon(Icons.photo_camera_outlined),
          ),
          IconButton(
            tooltip: tr('نسخ JSON'),
            onPressed: _copyJson,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: tr('نسخ نص الأقسام'),
            onPressed: _copyPlainText,
            icon: const Icon(Icons.notes_outlined),
          ),
          IconButton(
            tooltip: tr('حفظ الاستبيان'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LifexText('القسم ${_section + 1} من ${_sections.length}',
                    style: Theme.of(context).textTheme.labelLarge),
                Flexible(
                  child: LifexText(
                    current.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LifexText(
              'بيانات تنظيمية لملفك. ليست تشخيصاً ولا قراءة لصورة. '
              'التقاط التقارير من الكاميرا بعد موافقة ظاهرة.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          if (_consistencyAr != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LifexText(
                _consistencyAr!,
                style: const TextStyle(fontSize: 13, color: Colors.amber),
              ),
            ),
          SwitchListTile(
            title: const LifexText('نطق الحقل عند التركيز'),
            subtitle: const LifexText('للمكفوفين. يقرأ اسم الحقل فقط، بلا تشخيص'),
            value: _speakOnFocus,
            onChanged: (value) => setState(() => _speakOnFocus = value),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: current.fields.map(_buildQuestion).toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showConsistency,
                          child: const LifexText('تعارضات الإدخال'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showSummary,
                          child: const LifexText('ملخص إدخالي'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_section > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _section--);
                              _speakSection();
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const LifexText('السابق'),
                          ),
                        ),
                      if (_section > 0) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _section == _sections.length - 1
                              ? () {
                                  _save();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const StampedReportsScreen(),
                                    ),
                                  );
                                }
                              : () {
                                  setState(() => _section++);
                                  _speakSection();
                                },
                          icon: Icon(_section == _sections.length - 1
                              ? Icons.check
                              : Icons.arrow_forward),
                          label: LifexText(_section == _sections.length - 1
                              ? 'حفظ ثم التقرير المختوم'
                              : 'التالي'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(QuestionField question) {
    Widget child;
    switch (question.kind) {
      case QuestionKind.yesNo:
        child = Card(
          child: SwitchListTile(
            title: LifexText(question.label),
            value: _answers[question.key] == true,
            onChanged: (value) =>
                setState(() => _answers[question.key] = value),
          ),
        );
        break;
      case QuestionKind.choice:
        final current = _answers[question.key] as String?;
        final safeValue =
            question.options!.contains(current) ? current : null;
        child = Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: safeValue,
            decoration: InputDecoration(labelText: tr(question.label)),
            items: question.options!
                .map((option) =>
                    DropdownMenuItem(value: option, child: LifexText(option)))
                .toList(),
            onChanged: (value) =>
                setState(() => _answers[question.key] = value),
          ),
        );
        break;
      case QuestionKind.photo:
        child = Card(
          child: ListTile(
            title: LifexText(question.label),
            subtitle: LifexText(
              (_answers[question.key] ?? 'لم تُلتقط بعد. الكاميرا إشارة تقريبية.').toString(),
            ),
            trailing: const Icon(Icons.camera_alt_outlined),
            onTap: () => _capturePhoto(question),
          ),
        );
        break;
      case QuestionKind.number:
      case QuestionKind.text:
        child = Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controllerFor(question),
                  keyboardType: question.kind == QuestionKind.number
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.multiline,
                  maxLines: question.kind == QuestionKind.number ? 1 : 3,
                  decoration: InputDecoration(
                    labelText: tr(question.label),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => _answers[question.key] = value,
                ),
              ),
              VoiceFillButton(
                onText: (text) {
                  final controller = _controllerFor(question);
                  controller.text = controller.text.isEmpty
                      ? text
                      : '${controller.text} $text';
                  _answers[question.key] = controller.text;
                },
              ),
            ],
          ),
        );
    }
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) _maybeSpeakField(question.label);
      },
      child: child,
    );
  }
}
