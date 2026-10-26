/// مدخل تعديل السجلات الشخصية من القائمة.
library lifex_ai.screens.data_records_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/lifex_record_edit.dart';
import 'appointments_screen.dart';
import 'doctor_directory_screen.dart';
import 'emergency_contacts_screen.dart';
import 'family_management_screen.dart';
import 'medications_screen.dart';

class DataRecordsScreen extends StatelessWidget {
  const DataRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ActiveProfileController>();
    final profile = controller.activeProfile;
    final profileId = controller.activeProfileId;
    return Scaffold(
      appBar: AppBar(
        title: Text(lifexUi('تعديل البيانات', 'Edit records')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(lifexUi(
            'التعديل للسجل الشخصي على هذا الجهاز. المرجع العام لا يُستبدل كحقيقة، والجرعة لا تُغيَّر من هنا.',
            'Edit applies to your personal record on this device. General reference is not replaced as fact, and a dose is not changed here.',
          )),
          const SizedBox(height: 12),
          _RecordRow(
            title: lifexUi('الملف الصحي', 'Health profile'),
            subtitle: profile?.fullName ??
                lifexUi('لا ملف نشط', 'No active profile'),
            onEdit: () async {
              if (profile == null) {
                _needProfile(context);
                return;
              }
              final next = await lifexEditText(
                context,
                titleAr: 'تعديل الاسم',
                titleEn: 'Edit the name',
                labelAr: 'الاسم',
                labelEn: 'Name',
                initial: profile.fullName,
              );
              final name = next?.trim() ?? '';
              if (name.isEmpty) return;
              profile.fullName = name;
              controller.notifyProfileChanged();
            },
          ),
          _RecordRow(
            title: lifexUi('الأدوية', 'Medications'),
            subtitle: lifexUi(
              'اسم الدواء كما كتبته. بلا جرعة.',
              'The medicine name as you wrote it. No dose.',
            ),
            onEdit: () {
              if (profileId == null) {
                _needProfile(context);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MedicationsScreen(profileId: profileId),
                ),
              );
            },
          ),
          _RecordRow(
            title: lifexUi('المواعيد', 'Appointments'),
            subtitle: lifexUi(
              'الموعد المحلي القابل للتعديل يظهر زرّه في القائمة.',
              'A local appointment that can be edited shows its button in the list.',
            ),
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
          ),
          _RecordRow(
            title: lifexUi('العائلة', 'Family'),
            subtitle: lifexUi(
              'تعديل الاسم الظاهر لفرد موجود. لا يفتح ملف شخص آخر.',
              'Edit the shown name of an existing member. It does not open another person\'s file.',
            ),
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FamilyManagementScreen()),
            ),
          ),
          _RecordRow(
            title: lifexUi('جهات الطوارئ', 'Emergency contacts'),
            subtitle: lifexUi('الاسم ووسيلة الاتصال المحفوظة.', 'The saved name and contact.'),
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EmergencyContactsScreen(),
              ),
            ),
          ),
          _RecordRow(
            title: lifexUi('الأطباء المحفوظون', 'Saved doctors'),
            subtitle: lifexUi(
              'سجل الطبيب المحلي على هذا الجهاز.',
              'The local doctor record on this device.',
            ),
            onEdit: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DoctorDirectoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _needProfile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(BlindNavigationCopy.needsProfileText)),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.title,
    required this.subtitle,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: LifexRecordEditButton(onPressed: onEdit),
        onTap: onEdit,
      ),
    );
  }
}
