/// =============================================================
/// Lifex-AI — شاشة الدورة التشغيلية
/// الشكوى والاقتراح والاعتماد والحجز والطلب. بلا تشخيص وبلا دفع ناجح.
/// =============================================================
library lifex_ai.screens.care_cycle_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/care_cycle/care_cycle_desk.dart';
import '../features/doctors/doctor_directory.dart';
import '../features/location/device_location_reader.dart';
import '../features/location/unit_place_stamp.dart';
import '../features/location/nearby_care_finder.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';

class CareCycleScreen extends StatefulWidget {
  const CareCycleScreen({super.key});

  @override
  State<CareCycleScreen> createState() => _CareCycleScreenState();
}

class _CareCycleScreenState extends State<CareCycleScreen> {
  static const _desk = CareCycleDesk();
  static const _reader = DeviceLocationReader();

  final _complaint = TextEditingController();
  final _duration = TextEditingController();
  final _severity = TextEditingController();
  final _doctorName = TextEditingController();
  final _slotTime = TextEditingController(text: '09:00');
  final _pharmacyName = TextEditingController();
  final _code = TextEditingController();
  final _units = TextEditingController(text: '1');
  final _substance = TextEditingController();
  final _dose = TextEditingController();
  final _form = TextEditingController();
  final _course = TextEditingController();
  final _instructions = TextEditingController();
  final _amount = TextEditingController();

  String _status = 'اكتب الشكوى. التقرير الأولي ليس تشخيصاً.';
  String _specialty = DoctorDirectory.specialtiesAr.first;
  String _unitKind = 'مختبر';
  bool _shareFull = false;
  bool _speak = true;
  bool _busy = false;
  CareReport? _report;
  NearbyCareReport? _places;
  ServiceQuote? _quote;
  String? _doctorId;
  String? _pharmacyId;

  static const _unitsKinds = [
    'مختبر',
    'أشعة',
    'مستشفى',
    'أسنان',
    'تأهيل',
    'أطراف',
    'بنك دم',
  ];

  @override
  void dispose() {
    _complaint.dispose();
    _duration.dispose();
    _severity.dispose();
    _doctorName.dispose();
    _slotTime.dispose();
    _pharmacyName.dispose();
    _code.dispose();
    _units.dispose();
    _substance.dispose();
    _dose.dispose();
    _form.dispose();
    _course.dispose();
    _instructions.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _say(String text) async {
    setState(() => _status = text);
    if (_speak && text.trim().isNotEmpty) {
      await VoiceEngine.instance.speak(text);
    }
  }

  HealthProfile? _byId(ActiveProfileController controller, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final profile in controller.allProfiles) {
      if (profile.profileId == id) return profile;
    }
    return null;
  }

  Future<void> _analyze(HealthProfile patient) async {
    final report = _desk.report(
      complaint: _complaint.text,
      duration: _duration.text,
      severity: _severity.text,
      patient: patient,
    );
    setState(() {
      _report = report;
      _specialty = report.specialtyAr;
    });
    await _say('${report.summaryAr} ${report.hypothesesAr.join(' ')}');
  }

  Future<void> _locate(HealthProfile patient) async {
    final controller = context.read<ActiveProfileController>();
    setState(() => _busy = true);
    final read = await _reader.read();
    if (!mounted) return;
    final store = ProfileBoxStore(patient);
    final fix = read.fix;
    if (fix != null) {
      final address = store.stringField(BoxKeys.residencePlace) ?? '';
      final stamp = const UnitPlaceStamp().writeDeviceFix(
        unit: patient,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyMeters: fix.accuracyMeters,
        knownAddress: address,
      );
      if (stamp.wrote) {
        controller.saveActiveProfileChanges();
      }
    }
    final profiles = controller.allProfiles;
    final report = _desk.suggest(
      latitude: read.fix?.latitude,
      longitude: read.fix?.longitude,
      specialty: _specialty,
      boxes: [
        CareBox(
          kindAr: 'طبيب',
          specialtyApplies: true,
          rows: store.list(BoxKeys.doctors),
        ),
        CareBox(kindAr: 'مستشفى', rows: store.list(BoxKeys.hospital)),
        CareBox(kindAr: 'مختبر', rows: store.list(BoxKeys.labs)),
        CareBox(kindAr: 'صيدلية', rows: store.list(BoxKeys.pharmacy)),
        CareBox(kindAr: 'أشعة', rows: store.list(BoxKeys.radiology)),
        CareBox(kindAr: 'أسنان', rows: store.list(BoxKeys.dental)),
        CareBox(
          kindAr: 'وحدة مسجّلة',
          rows: UnitPlaceStamp.rowsFromProfiles(profiles),
        ),
      ],
    );
    setState(() {
      _places = report;
      _busy = false;
    });
    await _say(
      read.hasFix
          ? '${read.messageAr} الأقرب من إحداثيات الجهاز وسجلات الوحدات التي لها موقع مكتوب.'
          : read.messageAr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final patient = controller.activeProfile;
        if (patient == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('دورة الرعاية')),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final others = controller.allProfiles
            .where((item) => item.profileId != patient.profileId)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('دورة الرعاية'),
            actions: [
              IconButton(
                tooltip: _speak ? 'إيقاف النطق' : 'تشغيل النطق',
                onPressed: () => setState(() => _speak = !_speak),
                icon: Icon(_speak ? Icons.volume_up : Icons.volume_off),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'التقرير احتمال للمراجعة. الطوارئ تسبق الموعد العادي. السيرة الكاملة لا تُرسل إلا بموافقتك. الدفع يبقى قيد الانتظار حتى يربط مزود مرخّص. لا تُخزَّن بيانات البطاقة.',
              ),
              TextField(
                controller: _complaint,
                decoration: const InputDecoration(labelText: 'الشكوى الحالية'),
              ),
              TextField(
                controller: _duration,
                decoration: const InputDecoration(labelText: 'المدة'),
              ),
              TextField(
                controller: _severity,
                decoration: const InputDecoration(labelText: 'الشدة'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _analyze(patient),
                child: const Text('تقرير أولي'),
              ),
              Text(_status),
              if (_report?.urgent == true)
                const Text('التوجه إلى الطوارئ يسبق البحث عن موعد عادي.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _specialty,
                decoration: const InputDecoration(labelText: 'الاختصاص'),
                items: [
                  for (final item in DoctorDirectory.specialtiesAr)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _specialty = value);
                },
              ),
              FilledButton(
                onPressed: _busy ? null : () => _locate(patient),
                child: const Text('أقرب اختصاص من موقعي'),
              ),
              if (_places != null) ...[
                for (final place in [..._places!.doctors, ..._places!.units])
                  ListTile(
                    title: Text('${place.kindAr}: ${place.title}'),
                    subtitle: Text(
                      place.ranked
                          ? '${place.km!.toStringAsFixed(1)} كم — ${place.detail}'
                          : 'بلا ترتيب مسافة. ${place.detail}',
                    ),
                  ),
              ],
              TextField(
                controller: _doctorName,
                decoration: const InputDecoration(labelText: 'اسم الطبيب'),
              ),
              DropdownButtonFormField<String?>(
                value: _doctorId,
                decoration: const InputDecoration(
                  labelText: 'ملف الطبيب على هذا الجهاز',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('لا ملف')),
                  for (final item in others)
                    DropdownMenuItem(
                      value: item.profileId,
                      child: Text(item.fullName),
                    ),
                ],
                onChanged: (value) => setState(() => _doctorId = value),
              ),
              CheckboxListTile(
                value: _shareFull,
                onChanged: (value) =>
                    setState(() => _shareFull = value ?? false),
                title: const Text('أوافق على إرسال السيرة التي أكتبها للطبيب'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              FilledButton(
                onPressed: () async {
                  final doctor = _byId(controller, _doctorId);
                  final name = _doctorName.text.trim().isEmpty
                      ? (doctor?.fullName ?? '')
                      : _doctorName.text.trim();
                  if (name.isEmpty) {
                    await _say('اكتب اسم الطبيب أو اختر ملفه.');
                    return;
                  }
                  final result = _desk.accredit(
                    patient: patient,
                    doctor: doctor,
                    doctorName: name,
                    complaint: _complaint.text,
                    shareFullRecord: _shareFull,
                    fullRecordText: _report?.hypothesesAr.join(' ') ?? '',
                  );
                  controller.saveActiveProfileChanges();
                  await _say(result.messageAr);
                },
                child: const Text('طبيبي المعتمد'),
              ),
              TextField(
                controller: _slotTime,
                decoration: const InputDecoration(labelText: 'وقت الحصة'),
              ),
              FilledButton(
                onPressed: () async {
                  final doctor = _byId(controller, _doctorId);
                  if (doctor == null) {
                    await _say('حجز الحصة يحتاج ملف الطبيب على هذا الجهاز.');
                    return;
                  }
                  final blocked = _desk.holdDoctorSlot(
                    doctor: doctor,
                    patient: patient,
                    day: DateTime.now(),
                    time: _slotTime.text.trim(),
                    workHours: 12,
                    examMinutes: 30,
                    startHour: 8,
                  );
                  controller.saveActiveProfileChanges();
                  await _say(blocked ?? 'حُفظت الحصة على جهاز الطبيب.');
                },
                child: const Text('حجز الحصة'),
              ),
              DropdownButtonFormField<String>(
                value: _unitKind,
                decoration: const InputDecoration(labelText: 'وحدة أخرى'),
                items: [
                  for (final item in _unitsKinds)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _unitKind = value);
                },
              ),
              FilledButton(
                onPressed: () async {
                  final provider = _byId(controller, _doctorId);
                  if (provider == null) {
                    await _say('اختر ملف مقدم الخدمة على هذا الجهاز.');
                    return;
                  }
                  final now = DateTime.now();
                  final parts = _slotTime.text.trim().split(':');
                  final hour = int.tryParse(parts.first) ?? now.hour;
                  final minute =
                      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
                  final blocked = _desk.holdUnitSlot(
                    provider: provider,
                    patient: patient,
                    unitKind: _unitKind,
                    at: DateTime(now.year, now.month, now.day, hour, minute),
                  );
                  controller.saveActiveProfileChanges();
                  await _say(blocked ?? 'حُفظ طلب الوحدة على هذا الجهاز.');
                },
                child: const Text('طلب الوحدة'),
              ),
              const Divider(),
              TextField(
                controller: _substance,
                decoration: const InputDecoration(
                  labelText: 'المادة كما يكتبها الطبيب',
                ),
              ),
              TextField(
                controller: _dose,
                decoration: const InputDecoration(labelText: 'الجرعة'),
              ),
              TextField(
                controller: _form,
                decoration: const InputDecoration(labelText: 'الشكل الدوائي'),
              ),
              TextField(
                controller: _course,
                decoration: const InputDecoration(labelText: 'المدة'),
              ),
              TextField(
                controller: _instructions,
                decoration: const InputDecoration(labelText: 'التعليمات'),
              ),
              FilledButton(
                onPressed: () async {
                  final doctor = _byId(controller, _doctorId);
                  if (doctor == null) {
                    await _say('حفظ الوصفة يحتاج ملف الطبيب على هذا الجهاز.');
                    return;
                  }
                  final line = _desk.recordPrescription(
                    doctor: doctor,
                    patient: patient,
                    substance: _substance.text,
                    dose: _dose.text,
                    form: _form.text,
                    duration: _course.text,
                    instructions: _instructions.text,
                  );
                  controller.saveActiveProfileChanges();
                  await _say(line);
                },
                child: const Text('حفظ الوصفة'),
              ),
              TextField(
                controller: _pharmacyName,
                decoration: const InputDecoration(labelText: 'اسم الصيدلية'),
              ),
              DropdownButtonFormField<String?>(
                value: _pharmacyId,
                decoration: const InputDecoration(
                  labelText: 'ملف الصيدلية على هذا الجهاز',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('لا ملف')),
                  for (final item in others)
                    DropdownMenuItem(
                      value: item.profileId,
                      child: Text(item.fullName),
                    ),
                ],
                onChanged: (value) => setState(() => _pharmacyId = value),
              ),
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'رمز الصنف في دفتر الصيدلي',
                ),
              ),
              TextField(
                controller: _units,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
              FilledButton(
                onPressed: () async {
                  final pharmacy = _byId(controller, _pharmacyId);
                  final name = _pharmacyName.text.trim().isEmpty
                      ? (pharmacy?.fullName ?? '')
                      : _pharmacyName.text.trim();
                  if (name.isEmpty) {
                    await _say('اكتب اسم الصيدلية أو اختر ملفها.');
                    return;
                  }
                  final line = _desk.accreditPharmacy(
                    patient: patient,
                    pharmacy: pharmacy,
                    pharmacyName: name,
                  );
                  controller.saveActiveProfileChanges();
                  await _say(line);
                },
                child: const Text('صيدليتي المعتمدة'),
              ),
              FilledButton(
                onPressed: () async {
                  final line = _desk.requestCodedStock(
                    patient: patient,
                    pharmacy: _byId(controller, _pharmacyId),
                    code: _code.text,
                    units: int.tryParse(_units.text.trim()) ?? 0,
                  );
                  controller.saveActiveProfileChanges();
                  await _say(line);
                },
                child: const Text('طلب الكمية'),
              ),
              FilledButton(
                onPressed: () async {
                  final pharmacy = _byId(controller, _pharmacyId);
                  if (pharmacy == null) {
                    await _say('قبول الطلب يحتاج ملف الصيدلية على هذا الجهاز.');
                    return;
                  }
                  final line = _desk.acceptCodedStock(
                    pharmacy: pharmacy,
                    code: _code.text,
                    units: int.tryParse(_units.text.trim()) ?? 0,
                  );
                  controller.saveActiveProfileChanges();
                  await _say(line);
                },
                child: const Text('قبول الصيدلي وحجز الكمية'),
              ),
              const Divider(),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ بأصغر وحدة عملة',
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final quote = _desk.quote(
                    payer: patient,
                    grossMinor: int.tryParse(_amount.text.trim()) ?? 0,
                  );
                  setState(() => _quote = quote);
                  await _say(quote.messageAr);
                },
                child: const Text('عرض المبلغ والعمولة'),
              ),
              FilledButton(
                onPressed: _quote == null
                    ? null
                    : () async {
                        final next = _desk.requestRefund(_quote!);
                        setState(() => _quote = next);
                        await _say(next.messageAr);
                      },
                child: const Text('طلب استرداد'),
              ),
            ],
          ),
        );
      },
    );
  }
}
