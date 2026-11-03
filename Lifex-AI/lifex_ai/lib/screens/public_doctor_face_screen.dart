/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: public_doctor_face_screen.dart
/// صفحة عامة: نبذة واعتماد وصور عمل. بلا قوائم مرضى. الحجز للحصص الفارغة.
/// =============================================================
library lifex_ai.screens.public_doctor_face_screen;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/app_constants.dart';
import '../core/local_knowledge.dart';
import '../features/doctors/accredited_doctor_bond.dart';
import '../features/doctors/doctor_remote_slot.dart';
import '../features/doctors/public_slot_policy.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/cv_document_vault.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/cv_report_engine.dart';
import '../features/profile/health_profile.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
import 'health_chat_screen.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class PublicDoctorFaceScreen extends StatefulWidget {
  const PublicDoctorFaceScreen({super.key, required this.doctor});

  final Map<String, dynamic> doctor;

  @override
  State<PublicDoctorFaceScreen> createState() => _PublicDoctorFaceScreenState();
}

class _PublicDoctorFaceScreenState extends State<PublicDoctorFaceScreen> {
  static const _policy = PublicSlotPolicy();
  DateTime _day = DateTime.now();
  String? _statusAr;
  String _period = 'all';

  String get _doctorName => widget.doctor['title']?.toString() ?? 'طبيب';

  HealthProfile? _doctorProfile(ActiveProfileController controller) {
    final id = widget.doctor['profileId']?.toString() ?? '';
    if (id.isEmpty) return null;
    return controller.profileById(id);
  }

  int get _workHours =>
      int.tryParse(widget.doctor['workHours']?.toString() ?? '') ?? 12;
  int get _slotMinutes =>
      int.tryParse(widget.doctor['slotMinutes']?.toString() ?? '') ?? 30;
  int get _startHour =>
      int.tryParse(widget.doctor['startHour']?.toString() ?? '') ?? 9;

  String _publicId(HealthProfile? doctor) {
    if (doctor == null) return '';
    return HealthIdentityManager.instance
            .getByProfileId(doctor.profileId)
            ?.lifexId ??
        doctor.profileId;
  }

  Widget _line(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return LifexText('$label: $text');
  }

  String _discountLabel() {
    final raw = widget.doctor['discountSuggestion']?.toString().trim() ?? '';
    final percent = int.tryParse(raw);
    if (percent == null || percent < 0 || percent > 100) return '';
    return 'اقتراح خصم كتبه الطبيب: $percent٪. ليس تحصيلاً وليس إعفاءً مؤكداً.';
  }

  bool _inPeriod(String clock) {
    final hour = int.tryParse(clock.split(':').first) ?? 0;
    if (_period == 'am') return hour < 15;
    if (_period == 'pm') return hour >= 15;
    return true;
  }

  String _spokenCard(HealthProfile? doctor) {
    final id = _publicId(doctor);
    final parts = <String>[
      'الملف العام للطبيب $_doctorName.',
      if (id.isNotEmpty) 'المعرف $id.',
      'أسماء المرضى لا تُنطق هنا.',
    ];
    return parts.join(' ');
  }

  List<String> get _photos {
    final raw = widget.doctor['photos'];
    if (raw is List) {
      return [for (final item in raw) item.toString()];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: LifexText(_doctorName)),
            body: const Center(child: LifexText('لا يوجد ملف صحي نشط.')),
          );
        }
        final doctorProfile = _doctorProfile(controller);
        final isDoctorSelf = doctorProfile != null &&
            doctorProfile.profileId == profile.profileId;
        final clocks = _policy.clocksFor(
          workHours: _workHours,
          stepMinutes: _slotMinutes,
          startHour: _startHour,
        );
        return Scaffold(
          appBar: AppBar(title: const LifexText('الصفحة العامة للطبيب')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'عامة: اسم واختصاص واعتماد وصور عمل وتواصل. قوائم المرضى والأمراض داخل يوميات الطبيب فقط.',
              ),
              LifexText(AppConstants.ownershipStatementShort,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                label: tr('$_doctorName. المعرف ${_publicId(doctorProfile)}'),
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LifexText(_doctorName,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if (_publicId(doctorProfile).isNotEmpty)
                      SelectableText(
                        'ID ${_publicId(doctorProfile)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
              LifexText(widget.doctor['detail']?.toString() ?? ''),
              _line('المدينة', widget.doctor['city']),
              _line('العنوان', widget.doctor['address']),
              _line('البريد', widget.doctor['email']),
              _line('الهاتف', widget.doctor['phone']),
              _line('رقم الاعتماد الوطني', widget.doctor['license']),
              _line('ملاحظة الطبيب', widget.doctor['note']),
              _line('دعم ذوي الإعاقة', widget.doctor['disabilityNote']),
              if (_discountLabel().isNotEmpty) LifexText(_discountLabel()),
              const LifexText(
                'الخصوصية: الجدول ظاهر، وأسماء المرضى لا تظهر في هذا الملف العام.',
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => VoiceEngine.instance.speak(
                    _spokenCard(doctorProfile),
                  ),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const LifexText('انطق الملف العام'),
                ),
              ),
              if ((widget.doctor['brief']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LifexText(widget.doctor['brief'].toString()),
                ),
              LifexText('${widget.doctor['km'] ?? '—'} كم كما أدخلت'),
              const SizedBox(height: 8),
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final path in _photos)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Image.file(
                            File(path),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                width: 120, child: Icon(Icons.image)),
                          ),
                        ),
                    ],
                  ),
                ),
              if (isDoctorSelf)
                TextButton.icon(
                  onPressed: () => _addWorkPhoto(controller, profile),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const LifexText('إضافة صورة نموذج عمل'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => unawaited(
                        _accredit(controller, profile, doctorProfile)),
                    child: const LifexText('طبيبي المعتمد'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HealthChatScreen()),
                    ),
                    child: const LifexText('محادثة'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                title: LifexText(
                  'يوم ${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}',
                ),
                subtitle: LifexText(
                  '$_workHours ساعة عمل، كل $_slotMinutes دقيقة — حصص فارغة فقط',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _day,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setState(() => _day = picked);
                },
              ),
              if (_statusAr != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LifexText(_statusAr!,
                      style: const TextStyle(color: Colors.orange)),
                ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: LifexText('الفترتان')),
                  ButtonSegment(value: 'am', label: LifexText('صباحي')),
                  ButtonSegment(value: 'pm', label: LifexText('مسائي')),
                ],
                selected: {_period},
                onSelectionChanged: (value) =>
                    setState(() => _period = value.first),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final clock in clocks.where(_inPeriod))
                    ActionChip(
                      label: LifexText(
                        doctorProfile != null &&
                                !const DoctorRemoteSlot()
                                    .isEmptyAt(doctorProfile, _day, clock)
                            ? '$clock محجوز'
                            : clock,
                      ),
                      onPressed: () => _book(
                        controller,
                        profile,
                        doctorProfile,
                        clock,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addWorkPhoto(
    ActiveProfileController controller,
    HealthProfile me,
  ) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final photos = [..._photos, file.path];
    widget.doctor['photos'] = photos;
    final store = ProfileBoxStore(me);
    final doctors = store.list(BoxKeys.doctors);
    final index = doctors.indexWhere(
      (item) => item['title'] == _doctorName,
    );
    if (index >= 0) {
      doctors[index]['photos'] = photos;
      store.setList(BoxKeys.doctors, doctors);
    }
    controller.saveActiveProfileChanges();
    setState(() {});
  }

  Future<bool?> _askShareLevel() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: LifexText(lifexUi('ماذا يصل إلى الطبيب؟', 'What reaches the doctor?')),
        content: LifexText(lifexUi(
          'اختر ما يُرسل إلى ملف $_doctorName على هذا الجهاز. السيرة الكاملة تشمل اسمك الحقيقي ورقمك الوطني وحالاتك المزمنة وتقريرك.',
          'Choose what is sent to the file of $_doctorName on this device. The full record includes your real name, national number, chronic conditions, and report.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: LifexText(lifexUi('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: LifexText(lifexUi('الحد الأدنى فقط', 'Minimum only')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: LifexText(lifexUi(
              'اسمي الحقيقي والسيرة الكاملة',
              'My real name and the full record',
            )),
          ),
        ],
      ),
    );
  }

  Future<void> _accredit(
    ActiveProfileController controller,
    HealthProfile patient,
    HealthProfile? doctor,
  ) async {
    final shareFull = await _askShareLevel();
    if (shareFull == null || !mounted) return;
    if (!shareFull) {
      final result = const AccreditedDoctorBond().accredit(
        patient: patient,
        doctor: doctor,
        doctorName: _doctorName,
        cvPlainText: AccreditedDoctorBond.minimumText(
          patient: patient,
          doctorName: _doctorName,
        ),
      );
      controller.saveActiveProfileChanges();
      setState(() => _statusAr = result.messageAr);
      VoiceEngine.instance.speak(result.messageAr);
      return;
    }
    LocalKnowledge knowledge;
    try {
      knowledge = context.read<LocalKnowledge>();
    } catch (_) {
      knowledge = LocalKnowledge(
        diseases: const [],
        medications: const [],
        symptoms: const [],
        tests: const [],
        namedConditions: const [],
        cameraSigns: const [],
        disclaimerAr: '',
      );
    }
    final cv = const CvReportEngine()
        .compile(
          profile: patient,
          knowledge: knowledge,
          cameraNotes: ProfileBoxStore(patient).list(BoxKeys.cameraNotes),
          vault: CvDocumentVault(patient).all(),
        )
        .report
        .toPlainText();
    final result = const AccreditedDoctorBond().accredit(
      patient: patient,
      doctor: doctor,
      doctorName: _doctorName,
      cvPlainText: cv,
      shareFullRecord: true,
    );
    controller.saveActiveProfileChanges();
    setState(() => _statusAr = result.messageAr);
    VoiceEngine.instance.speak(result.messageAr);
  }

  void _book(
    ActiveProfileController controller,
    HealthProfile patient,
    HealthProfile? doctor,
    String clock,
  ) {
    if (doctor == null) {
      setState(() => _statusAr =
          'الحجز في يوميات الطبيب يحتاج ملف الطبيب على هذا الجهاز.');
      return;
    }
    final error = const DoctorRemoteSlot().book(
      doctor: doctor,
      patient: patient,
      day: _day,
      time: clock,
      workHours: _workHours,
      examMinutes: _slotMinutes,
      startHour: _startHour,
    );
    controller.saveActiveProfileChanges();
    setState(() =>
        _statusAr = error ?? 'حُجزت $clock باسمك الحقيقي على يوميات الطبيب.');
    VoiceEngine.instance.speak(_statusAr!);
  }
}
