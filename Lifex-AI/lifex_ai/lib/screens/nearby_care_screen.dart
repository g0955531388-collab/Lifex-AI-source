/// =============================================================
/// Lifex-AI — أقرب طبيب ووحدة من موقع الجهاز
/// الاختصاص والمسافة من سجلات الملف. بلا دليل مختلق.
/// =============================================================
library lifex_ai.screens.nearby_care_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/permission_transparency.dart';
import '../features/doctors/doctor_directory.dart';
import '../features/location/device_location_reader.dart';
import '../features/location/nearby_care_finder.dart';
import '../features/location/unit_place_stamp.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/barcode_scan_button.dart';
import '../widgets/honesty_banner.dart';

class NearbyCareScreen extends StatefulWidget {
  const NearbyCareScreen({super.key});

  @override
  State<NearbyCareScreen> createState() => _NearbyCareScreenState();
}

class _NearbyCareScreenState extends State<NearbyCareScreen> {
  static const _reader = DeviceLocationReader();
  static const _finder = NearbyCareFinder();

  final _name = TextEditingController();
  final _barcode = TextEditingController();
  String _specialty = DoctorDirectory.specialtiesAr.first;
  String _kind = 'doctor';
  DeviceFix? _fix;
  String _status = 'الموقع يُقرأ بعد موافقتك. لا يُقترح مكان بلا إحداثيات في الملف.';
  NearbyCareReport? _report;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _say(String line) async {
    if (!mounted) return;
    setState(() => _status = line);
    await VoiceEngine.instance.speak(line);
  }

  Future<void> _locate() async {
    if (_busy) return;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قراءة الموقع'),
        content: const Text(
          'يُقرأ موقع هذا الجهاز لاقتراح أقرب طبيب حسب الاختصاص، '
          'وأقرب مستشفى ومختبر وصيدلية وأشعة وطب أسنان من السجلات التي تحمل إحداثيات. '
          'ليس دليلاً وطنياً ولا تشخيصاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أوافق'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.location,
      granted: true,
    );
    setState(() => _busy = true);
    final read = await _reader.read();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _fix = read.fix;
    });
    final profile = context.read<ActiveProfileController>().activeProfile;
    var stampLine = '';
    final fix = read.fix;
    if (profile != null && fix != null) {
      final address =
          ProfileBoxStore(profile).stringField(BoxKeys.residencePlace) ?? '';
      final stamp = const UnitPlaceStamp().writeDeviceFix(
        unit: profile,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyMeters: fix.accuracyMeters,
        knownAddress: address,
      );
      if (stamp.wrote) {
        context.read<ActiveProfileController>().saveActiveProfileChanges();
      }
      stampLine = ' ${stamp.messageAr}';
    }
    _refresh();
    await _say('${_spokenLine(read.messageAr)}$stampLine');
  }

  void _refresh() {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null || _fix == null) {
      setState(() => _report = null);
      return;
    }
    final store = ProfileBoxStore(profile);
    final profiles = context.read<ActiveProfileController>().allProfiles;
    setState(() {
      _report = _finder.suggest(
        hereLat: _fix!.latitude,
        hereLon: _fix!.longitude,
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
    });
  }

  String _spokenLine(String located) {
    final report = _report;
    if (_fix == null || report == null) return located;
    final rankedDoctors = report.doctors.where((item) => item.ranked).toList();
    final rankedUnits = report.units.where((item) => item.ranked).toList();
    if (rankedDoctors.isEmpty && rankedUnits.isEmpty) {
      return '$located لا سجل في الملف يحمل إحداثيات، فلم يُقترح الأقرب.';
    }
    final doctorLine = rankedDoctors.isEmpty
        ? 'لا طبيب بهذا الاختصاص له موقع مسجّل.'
        : 'أقرب طبيب $_specialty: ${rankedDoctors.first.title} على ${rankedDoctors.first.km!.toStringAsFixed(1)} كم.';
    final unitLine = rankedUnits.isEmpty
        ? 'لا وحدة بهذا الاختصاص لها موقع مسجّل.'
        : 'أقرب وحدة في $_specialty: ${rankedUnits.first.kindAr} ${rankedUnits.first.title} على ${rankedUnits.first.km!.toStringAsFixed(1)} كم.';
    return '$located $doctorLine $unitLine';
  }

  void _saveHere() {
    final fix = _fix;
    final profile = context.read<ActiveProfileController>().activeProfile;
    final name = _name.text.trim();
    if (fix == null) {
      _say('اقرأ الموقع أولاً ثم احفظ المكان.');
      return;
    }
    if (profile == null) {
      _say('أنشئ الملف الصحي أولاً. المكان لم يُحفظ.');
      return;
    }
    if (name.isEmpty) {
      _say('اكتب اسم المكان قبل الحفظ.');
      return;
    }
    final store = ProfileBoxStore(profile);
    final scanned = _barcode.text.trim();
    final row = {
      'title': name,
      'latitude': fix.latitude,
      'longitude': fix.longitude,
      'gpsRecorded': true,
      if (scanned.isNotEmpty) 'barcode': scanned,
    };
    switch (_kind) {
      case 'hospital':
        store.add(BoxKeys.hospital, {
          ...row,
          'detail': 'مستشفى. الموقع من جهاز المستخدم.',
        });
      case 'lab':
        store.add(BoxKeys.labs, {
          ...row,
          'detail': 'مختبر. الموقع من جهاز المستخدم.',
        });
      case 'pharmacy':
        store.add(BoxKeys.pharmacy, {
          ...row,
          'detail': 'صيدلية. الموقع من جهاز المستخدم.',
        });
      case 'radiology':
        store.add(BoxKeys.radiology, {
          ...row,
          'detail': 'أشعة. الموقع من جهاز المستخدم.',
        });
      case 'dental':
        store.add(BoxKeys.dental, {
          ...row,
          'detail': 'أسنان. الموقع من جهاز المستخدم.',
        });
      default:
        store.add(BoxKeys.doctors, {
          ...row,
          'detail': '$_specialty — موقع العيادة من الجهاز',
          'specialty': _specialty,
        });
    }
    context.read<ActiveProfileController>().saveActiveProfileChanges();
    _name.clear();
    _barcode.clear();
    _refresh();
    _say('حُفظ $name بإحداثيات الجهاز. الاقتراح يعيد الترتيب.');
  }

  Widget _placeTile(RankedCarePlace place) {
    final distance = place.km == null
        ? 'بلا إحداثيات في السجل، فلم يُحسب الأقرب'
        : '${place.km!.toStringAsFixed(1)} كم من موقع الجهاز';
    return ListTile(
      title: Text('${place.kindAr}: ${place.title}'),
      subtitle: Text('$distance\n${place.detail}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final fix = _fix;
    return Scaffold(
      appBar: AppBar(title: const Text('الأقرب من موقعي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'الأقرب يعني نفس الاختصاص ثم أقرب إحداثيات مسجّلة. مكان باختصاص آخر أو بلا موقع لا يُعرض كأنه الأقرب.',
          ),
          const SizedBox(height: 12),
          Text(_status),
          if (fix != null) ...[
            const SizedBox(height: 8),
            Text(
              'موقع الجهاز ${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}'
              '${fix.accuracyMeters == null ? '' : ' · دقة ${fix.accuracyMeters!.round()} م'}',
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _locate,
            icon: const Icon(Icons.my_location),
            label: Text(_busy ? 'يقرأ الموقع...' : 'اقرأ موقعي واقترح الأقرب'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _specialty,
            items: DoctorDirectory.specialtiesAr
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _specialty = value);
              if (_fix != null) _refresh();
            },
            decoration: const InputDecoration(labelText: 'اختصاص الطبيب'),
          ),
          if (report != null) ...[
            const SizedBox(height: 16),
            Text('أطباء $_specialty', style: Theme.of(context).textTheme.titleMedium),
            if (report.doctors.isEmpty)
              const ListTile(title: Text('لا طبيب بهذا الاختصاص في الملف'))
            else
              for (final place in report.doctors) _placeTile(place),
            const SizedBox(height: 8),
            Text(
              'وحدات $_specialty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (report.units.isEmpty)
              const ListTile(
                title: Text('لا وحدة بهذا الاختصاص في الملف'),
              )
            else
              for (final place in report.units) _placeTile(place),
          ],
          const Divider(height: 32),
          Text('تسجيل مكان بإحداثيات الجهاز', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _kind,
            items: const [
              DropdownMenuItem(value: 'doctor', child: Text('طبيب')),
              DropdownMenuItem(value: 'hospital', child: Text('مستشفى')),
              DropdownMenuItem(value: 'lab', child: Text('مختبر')),
              DropdownMenuItem(value: 'pharmacy', child: Text('صيدلية')),
              DropdownMenuItem(value: 'radiology', child: Text('أشعة')),
              DropdownMenuItem(value: 'dental', child: Text('أسنان')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _kind = value);
            },
            decoration: const InputDecoration(labelText: 'نوع المكان'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 8),
          BarcodeScanButton(
            current: _barcode.text,
            onCode: (code) => setState(() => _barcode.text = code),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveHere,
            child: const Text('احفظ هذا المكان بموقعي الحالي'),
          ),
        ],
      ),
    );
  }
}
