/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: doctor_directory_screen.dart
/// اختصاص ثم الأقرب فالأبعد بمسافة يدخلها المستخدم.
/// =============================================================
library lifex_ai.screens.doctor_directory_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../features/doctors/doctor_directory.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../widgets/barcode_scan_button.dart';
import '../widgets/lifex_record_edit.dart';
import '../widgets/honesty_banner.dart';
import 'doctor_diary_screen.dart';
import 'nearby_care_screen.dart';
import 'public_doctor_face_screen.dart';

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  String? _filter;
  String _specialty = DoctorDirectory.specialtiesAr.first;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _km = TextEditingController(text: '1');
  final _license = TextEditingController();
  final _brief = TextEditingController();
  final _barcode = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _disabilityNote = TextEditingController();
  final _discount = TextEditingController();
  String? _linkedProfileId;

  String _listedId(Map<String, dynamic> doctor) {
    final profileId = doctor['profileId']?.toString() ?? '';
    if (profileId.isEmpty) return '';
    final lifexId =
        HealthIdentityManager.instance.getByProfileId(profileId)?.lifexId;
    final shown = (lifexId == null || lifexId.isEmpty) ? profileId : lifexId;
    return '  ID $shown';
  }

  Future<void> _editDoctor(
    ProfileBoxStore store,
    ActiveProfileController controller,
    Map<String, dynamic> doctor,
  ) async {
    final id = doctor['id']?.toString() ?? '';
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lifexUi(
            'هذا السطر بلا معرّف محلي، فلا يُستبدل.',
            'This row has no local id, so it is not replaced.',
          )),
        ),
      );
      return;
    }
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DoctorEditDialog(doctor: doctor),
    );
    if (result == null || !mounted) return;
    final next = Map<String, dynamic>.from(doctor);
    next['title'] = result['title'];
    next['phone'] = result['phone'];
    next['detail'] = '${result['specialty']} — ${result['phone']}';
    final saved = store.replaceById(BoxKeys.doctors, id, next);
    if (!saved) return;
    controller.saveActiveProfileChanges();
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _km.dispose();
    _license.dispose();
    _brief.dispose();
    _city.dispose();
    _address.dispose();
    _email.dispose();
    _note.dispose();
    _disabilityNote.dispose();
    _discount.dispose();
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('الأطباء')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'EMPTY — وحدة الأطباء متاحة.\n'
                  'لا يوجد ملف صحي نشط بعد.\n'
                  'أنشئ ملفاً لإضافة أطباء محليين. ليس ACCESS DENIED.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final store = ProfileBoxStore(profile);
        final doctors = DoctorDirectory().nearestFirst(
          store.list(BoxKeys.doctors),
          specialty: _filter,
        );
        return Scaffold(
          appBar: AppBar(title: const Text('الأطباء')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'الصفحة العامة: اسم واختصاص وتواصل. بلا أسماء مرضى. الأقرب من موقع الجهاز في شاشة الاقتراح، وبلا إحداثيات مختلقة.',
              ),
              if (doctors.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(lifexUi('لا أطباء محفوظون', 'No doctors saved')),
                    subtitle: const Text(
                      'EMPTY — لا أطباء محفوظين على هذا الجهاز بعد. '
                      'أضف طبيباً أدناه. الدليل العام يبقى مفتوحاً.',
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.near_me_outlined),
                title: const Text('الأقرب من موقعي'),
                subtitle: const Text('الأقرب ضمن الاختصاص ثم ضمن موقع الجهاز'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NearbyCareScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('يوميات الطبيب'),
                subtitle: const Text('حصص اليوم على هذا الجهاز'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorDiaryScreen(),
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _filter ?? '__all__',
                items: [
                  const DropdownMenuItem(value: '__all__', child: Text('الكل')),
                  ...DoctorDirectory.specialtiesAr.map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _filter = value == '__all__' ? null : value,
                ),
                decoration: const InputDecoration(labelText: 'كل الاختصاصات'),
              ),
              for (final doctor in doctors)
                ListTile(
                  title: Text(
                    '${doctor['title'] ?? ''}'
                    '${_listedId(doctor)}',
                  ),
                  subtitle: Text(
                    '${doctor['detail']} · ${doctor['km'] ?? '—'} كم',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicDoctorFaceScreen(doctor: doctor),
                    ),
                  ),
                  trailing: LifexRecordEditButton(
                    onPressed: () => _editDoctor(store, controller, doctor),
                  ),
                ),
              const Divider(),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الطبيب'),
              ),
              DropdownButtonFormField<String>(
                value: _specialty,
                items: DoctorDirectory.specialtiesAr
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _specialty = value);
                },
                decoration: const InputDecoration(labelText: 'الاختصاص'),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'هاتف أو عنوان'),
              ),
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المسافة كم'),
              ),
              TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'المدينة'),
              ),
              TextField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'البريد'),
              ),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة الحضور التي يكتبها الطبيب',
                ),
              ),
              TextField(
                controller: _disabilityNote,
                decoration: const InputDecoration(
                  labelText: 'دعم ذوي الإعاقة الذي يعلنه الطبيب',
                ),
              ),
              TextField(
                controller: _discount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'اقتراح خصم بالمئة، إن كتبه الطبيب',
                ),
              ),
              TextField(
                controller: _license,
                decoration: const InputDecoration(
                  labelText: 'رقم الاعتماد الوطني',
                ),
              ),
              TextField(
                controller: _brief,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نبذة الإعلان العامة',
                ),
              ),
              DropdownButtonFormField<String>(
                value: _linkedProfileId ?? '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('بلا ملف طبيب على الجهاز'),
                  ),
                  ...controller.allProfiles.map(
                    (item) => DropdownMenuItem(
                      value: item.profileId,
                      child: Text('ملف: ${item.fullName}'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                    () => _linkedProfileId = value == '' ? null : value),
                decoration: const InputDecoration(
                  labelText: 'ربط بملف الطبيب لاستلام الإشعار والسي في',
                ),
              ),
              BarcodeScanButton(
                current: _barcode.text,
                onCode: (code) => setState(() => _barcode.text = code),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty) return;
                  store.add(BoxKeys.doctors, {
                    'title': _name.text.trim(),
                    'detail': '$_specialty — ${_phone.text.trim()}',
                    'km': _km.text.trim(),
                    'license': _license.text.trim(),
                    'brief': _brief.text.trim(),
                    'city': _city.text.trim(),
                    'address': _address.text.trim(),
                    'email': _email.text.trim(),
                    'phone': _phone.text.trim(),
                    'note': _note.text.trim(),
                    'disabilityNote': _disabilityNote.text.trim(),
                    'discountSuggestion': _discount.text.trim(),
                    if (_barcode.text.trim().isNotEmpty)
                      'barcode': _barcode.text.trim(),
                    'profileId': _linkedProfileId ?? '',
                    'workHours': '12',
                    'slotMinutes': '30',
                    'startHour': '9',
                    'photos': <String>[],
                  });
                  controller.saveActiveProfileChanges();
                  _name.clear();
                  _phone.clear();
                  _license.clear();
                  _brief.clear();
                  _barcode.clear();
                  _city.clear();
                  _address.clear();
                  _email.clear();
                  _note.clear();
                  _disabilityNote.clear();
                  _discount.clear();
                },
                child: const Text('حفظ طبيب محلي'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DoctorEditDialog extends StatefulWidget {
  const _DoctorEditDialog({required this.doctor});

  final Map<String, dynamic> doctor;

  @override
  State<_DoctorEditDialog> createState() => _DoctorEditDialogState();
}

class _DoctorEditDialogState extends State<_DoctorEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late String _specialty;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.doctor['title']?.toString() ?? '');
    _phone = TextEditingController(text: widget.doctor['phone']?.toString() ?? '');
    final detail = widget.doctor['detail']?.toString() ?? '';
    var specialty = DoctorDirectory.specialtiesAr.first;
    for (final item in DoctorDirectory.specialtiesAr) {
      if (detail.contains(item)) {
        specialty = item;
        break;
      }
    }
    _specialty = specialty;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(lifexUi('تعديل الطبيب المحلي', 'Edit the local doctor')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: lifexUi('الاسم', 'Name'),
              ),
            ),
            DropdownButtonFormField<String>(
              value: _specialty,
              items: DoctorDirectory.specialtiesAr
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _specialty = value);
              },
              decoration: InputDecoration(
                labelText: lifexUi('الاختصاص', 'Specialty'),
              ),
            ),
            TextField(
              controller: _phone,
              decoration: InputDecoration(
                labelText: lifexUi('الهاتف أو العنوان', 'Phone or address'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lifexUi('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _name.text.trim(),
              'phone': _phone.text.trim(),
              'specialty': _specialty,
            });
          },
          child: Text(lifexUi('حفظ', 'Save')),
        ),
      ],
    );
  }
}
