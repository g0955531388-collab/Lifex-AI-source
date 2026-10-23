/// إعدادات نداء الدم داخل الملف. لا تشخّص ولا تحذف المحادثات.
library lifex_ai.features.blood_network.blood_donation_prefs_card;

import 'package:flutter/material.dart';

import '../profile/health_profile.dart';

class BloodDonationPrefsCard extends StatefulWidget {
  const BloodDonationPrefsCard({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final HealthProfile profile;
  final VoidCallback onChanged;

  @override
  State<BloodDonationPrefsCard> createState() => _BloodDonationPrefsCardState();
}

class _BloodDonationPrefsCardState extends State<BloodDonationPrefsCard> {
  late final TextEditingController _city;
  late final TextEditingController _radius;

  @override
  void initState() {
    super.initState();
    final data = widget.profile.questionnaireData;
    _city = TextEditingController(text: data['bloodCity']?.toString() ?? '');
    final radius = data['bloodRadiusKm'];
    _radius = TextEditingController(text: radius is num ? '$radius' : '');
  }

  @override
  void dispose() {
    _city.dispose();
    _radius.dispose();
    super.dispose();
  }

  Set<String> get _channels {
    final raw = widget.profile.questionnaireData['bloodChannels'];
    if (raw is! List) return {};
    return raw.map((item) => item.toString()).toSet();
  }

  void _saveChannels(Set<String> channels) {
    widget.profile.questionnaireData['bloodChannels'] = channels.toList();
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إشعارات التبرع بالدم',
                style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل إشعارات التبرع بالدم'),
              subtitle: const Text(
                  'الإيقاف يوقف النداءات القادمة ولا يحذف المحادثات.'),
              value: widget.profile.acceptsBloodDonationAlerts,
              onChanged: (value) {
                widget.profile.acceptsBloodDonationAlerts = value;
                if (value && channels.isEmpty) {
                  widget.profile.questionnaireData['bloodChannels'] = [
                    'system'
                  ];
                }
                widget.onChanged();
                setState(() {});
              },
            ),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'المدينة المفضلة'),
              onChanged: (value) {
                widget.profile.questionnaireData['bloodCity'] = value.trim();
                widget.onChanged();
              },
            ),
            TextField(
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'نصف القطر المفضل بالكيلومتر',
              ),
              onChanged: (value) {
                widget.profile.questionnaireData['bloodRadiusKm'] =
                    double.tryParse(value.trim());
                widget.onChanged();
              },
            ),
            for (final channel in const [
              ('push', 'إشعار على الجهاز'),
              ('system', 'رسالة النظام'),
              ('public', 'المحادثة العامة للنداءات'),
              ('groups', 'المجموعات التي سمحت بالنشر'),
            ])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(channel.$2),
                value: channels.contains(channel.$1),
                onChanged: widget.profile.acceptsBloodDonationAlerts
                    ? (value) {
                        final next = {...channels};
                        if (value == true) {
                          next.add(channel.$1);
                        } else {
                          next.remove(channel.$1);
                        }
                        _saveChannels(next);
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
