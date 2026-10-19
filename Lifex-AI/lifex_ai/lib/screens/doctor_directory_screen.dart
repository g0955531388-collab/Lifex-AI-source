/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: doctor_directory_screen.dart
/// اختصاص ثم الأقرب فالأبعد بمسافة يدخلها المستخدم.
/// =============================================================
library lifex_ai.screens.doctor_directory_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/doctors/doctor_directory.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';
import 'doctor_diary_screen.dart';
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
  String? _linkedProfileId;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _km.dispose();
    _license.dispose();
    _brief.dispose();
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
                    'الصفحة العامة: اسم واختصاص وتواصل. بلا أسماء مرضى. الموقع الآلي يحتاج إذناً وخادماً؛ المسافة هنا يدوية.',
              ),
              if (doctors.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('No Doctors Found'),
                    subtitle: Text(
                      'EMPTY — لا أطباء محفوظين على هذا الجهاز بعد. '
                      'أضف طبيباً أدناه. الدليل العام يبقى مفتوحاً.',
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
                decoration:
                    const InputDecoration(labelText: 'كل الاختصاصات'),
              ),
              for (final doctor in doctors)
                ListTile(
                  title: Text(doctor['title']?.toString() ?? ''),
                  subtitle: Text(
                    '${doctor['detail']} · ${doctor['km'] ?? '—'} كم',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicDoctorFaceScreen(doctor: doctor),
                    ),
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
                onChanged: (value) =>
                    setState(() => _linkedProfileId = value == '' ? null : value),
                decoration: const InputDecoration(
                  labelText: 'ربط بملف الطبيب لاستلام الإشعار والسي في',
                ),
              ),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty) return;
                  store.add(BoxKeys.doctors, {
                    'title': _name.text.trim(),
                    'detail': '$_specialty — ${_phone.text.trim()}',
                    'km': _km.text.trim(),
                    'license': _license.text.trim(),
                    'brief': _brief.text.trim(),
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
