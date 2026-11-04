/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: appointments_screen.dart
/// المسار: lib/screens/appointments_screen.dart
/// الوصف: سجل مواعيد طبية محلي داخل الملف الصحي. ليس حجزاً مؤسسياً.
/// =============================================================
library lifex_ai.screens.appointments_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/profile/active_profile_controller.dart';
import '../widgets/record_management_actions.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    final raw = context
        .read<ActiveProfileController>()
        .activeProfile
        ?.questionnaireData['appointments'];
    if (raw is List) {
      _appointments = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }

  void _persist() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    profile.questionnaireData['appointments'] = _appointments;
    profile.lastUpdatedAt = DateTime.now();
    controller.saveActiveProfileChanges();
  }

  Future<void> _addAppointment() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AppointmentDialog(),
    );
    if (result == null) return;
    setState(() => _appointments.add(result));
    _persist();
  }

  Future<void> _editAppointment(int index) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AppointmentDialog(initial: _appointments[index]),
    );
    if (result == null) return;
    setState(() => _appointments[index] = result);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مواعيدي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAppointment,
        icon: const Icon(Icons.add),
        label: const Text('إضافة موعد'),
      ),
      body: _appointments.isEmpty
          ? const Center(child: Text('لا توجد مواعيد مسجلة.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final appointment = _appointments[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.event)),
                    title: Text(appointment['title']?.toString() ?? ''),
                    subtitle: Text(
                        '${appointment['date']} — ${appointment['place']}'),
                    trailing: RecordManagementActions(
                      onEdit: () => _editAppointment(index),
                      onDelete: () async {
                        setState(() => _appointments.removeAt(index));
                        _persist();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final record = widget.initial;
    if (record != null) {
      _title.text = record['title']?.toString() ?? '';
      _place.text = record['place']?.toString() ?? '';
      final rawDate = record['date']?.toString();
      if (rawDate != null) {
        final parts = rawDate.split('/');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null) {
            _date = DateTime(year, month, day);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة موعد' : 'تعديل الموعد'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _title,
              decoration:
                  const InputDecoration(labelText: 'نوع الموعد أو اسم الطبيب')),
          TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: 'المكان')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('التاريخ'),
            subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDate,
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'place':
                  _place.text.trim().isEmpty ? 'غير محدد' : _place.text.trim(),
              'date': '${_date.year}/${_date.month}/${_date.day}',
            });
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
