/// طلب دم على هذا الجهاز. التوزيع لا يغادر الملفات المحلية،
/// وبنك الدم يبقى صاحب قرار الأهلية.
library lifex_ai.screens.blood_request_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/blood_network/blood_appeal_banner_view.dart';
import '../features/blood_network/blood_appeal_desk.dart';
import '../features/blood_network/blood_request_engine.dart';
import '../features/blood_network/blood_type_match.dart';
import '../features/hospital/hospital_blood_bank.dart';
import '../features/messaging/chat_engine.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({super.key, this.preferType});

  final BloodTypeSimple? preferType;

  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  static const _desk = BloodAppealDesk();
  final _chat = ChatEngine();
  final _unitName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _contact = TextEditingController();
  final _reason = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _units = TextEditingController();
  late BloodTypeSimple _type = widget.preferType ?? BloodTypeSimple.oNegative;
  BloodRequestUrgency _urgency = BloodRequestUrgency.urgent;
  bool _allowExpansion = false;
  String _statusAr =
      'التوزيع على هذا الجهاز فقط. لا يوجد خادم يؤكد وصول النداء.';

  @override
  void dispose() {
    _unitName.dispose();
    _address.dispose();
    _city.dispose();
    _contact.dispose();
    _reason.dispose();
    _lat.dispose();
    _lon.dispose();
    _units.dispose();
    super.dispose();
  }

  Future<void> _send(ActiveProfileController profiles) async {
    final publisher = profiles.activeProfile;
    if (publisher == null) {
      setState(() => _statusAr = 'لا يوجد ملف نشط.');
      return;
    }
    final store = ProfileBoxStore(publisher);
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    final unitsText = _units.text.trim();
    final outcome = _desk.publish(
      unitStore: store,
      publisher: publisher,
      candidates: profiles.allProfiles,
      clientKey:
          '${_unitName.text.trim()}|${_type.name}|${_lat.text.trim()}|${_lon.text.trim()}',
      unitId: 'blood',
      unitName: _unitName.text,
      address: _address.text,
      latitude: lat ?? 0,
      longitude: lon ?? 0,
      bloodType: _type,
      urgency: _urgency,
      contact: _contact.text,
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      city: _city.text,
      reason: _reason.text,
      unitsNeeded: unitsText.isEmpty ? null : int.tryParse(unitsText),
      allowExpansion: _allowExpansion,
      chat: _chat,
    );
    profiles.notifyProfileChanged();
    setState(() {
      _statusAr = outcome.errorAr ??
          'سُجّل ${outcome.requestId} على هذا الجهاز. '
              'وُجهت دعوة أولية إلى ${outcome.invited}. '
              'لم يؤكد خادم خارجي الوصول، وبنك الدم يقرر الأهلية.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ActiveProfileController>();
    final donor = profiles.activeProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب دم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (donor != null)
            BloodAppealBannerView(
              donor: donor,
              profiles: profiles.allProfiles,
              onOpen: () {},
              onChanged: () => setState(() {}),
            ),
          const Text(
            'النداء الرسمي يصدر عن حساب مفوّض. الدعوة أولية وليست قبولًا طبيًا. '
            'الإرسال إلى هواتف خارج هذا الجهاز غير متاح.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitName,
            decoration: const InputDecoration(labelText: 'اسم الوحدة'),
          ),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'العنوان'),
          ),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'المدينة'),
          ),
          TextField(
            controller: _contact,
            decoration: const InputDecoration(labelText: 'وسيلة التواصل'),
          ),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'وصف الحاجة'),
          ),
          TextField(
            controller: _lat,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'خط العرض'),
          ),
          TextField(
            controller: _lon,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'خط الطول'),
          ),
          TextField(
            controller: _units,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد الوحدات، إن حُدّد',
            ),
          ),
          DropdownButtonFormField<BloodTypeSimple>(
            value: _type,
            decoration: const InputDecoration(labelText: 'الزمرة المطلوبة'),
            items: [
              for (final type in BloodTypeSimple.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(BloodTypeMatch.label(type)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          DropdownButtonFormField<BloodRequestUrgency>(
            value: _urgency,
            decoration: const InputDecoration(labelText: 'درجة الاستعجال'),
            items: const [
              DropdownMenuItem(
                value: BloodRequestUrgency.routine,
                child: Text('عادي'),
              ),
              DropdownMenuItem(
                value: BloodRequestUrgency.urgent,
                child: Text('عاجل'),
              ),
              DropdownMenuItem(
                value: BloodRequestUrgency.critical,
                child: Text('حرج'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _urgency = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('السماح بتوسيع النطاق داخل الحد'),
            subtitle: const Text('لا يتخطى ٤٠ كم ولا يغيّر المدينة.'),
            value: _allowExpansion,
            onChanged: (value) => setState(() => _allowExpansion = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _send(profiles),
            child: const Text('نشر النداء للمؤهلين على هذا الجهاز'),
          ),
          const SizedBox(height: 12),
          Text(_statusAr),
        ],
      ),
    );
  }
}
