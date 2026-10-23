/// دليل موارد الرؤية. يفتح صفحة الناشر ولا يثبّت نموذجاً.
library lifex_ai.screens.vision_resource_screen;

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/accessible_widgets.dart';
import '../features/accessibility/vision_model_update_desk.dart';
import '../features/knowledge/official_resource.dart';
import '../features/search/external_link_desk.dart';
import 'live_sight_screen.dart';

class VisionResourceScreen extends StatefulWidget {
  const VisionResourceScreen({super.key, this.profileId = ''});

  final String profileId;

  @override
  State<VisionResourceScreen> createState() => _VisionResourceScreenState();
}

class _VisionResourceScreenState extends State<VisionResourceScreen> {
  String? _note;
  bool _auto = true;
  bool _wifiOnly = true;

  @override
  void initState() {
    super.initState();
    _loadUpdatePrefs();
  }

  Future<void> _loadUpdatePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _auto = prefs.getBool(VisionModelUpdateDesk.autoKey) ?? true;
      _wifiOnly = prefs.getBool(VisionModelUpdateDesk.wifiKey) ?? true;
    });
    VisionModelUpdateDesk.instance.applyPrefs(auto: _auto, wifi: _wifiOnly);
  }

  Future<void> _saveUpdatePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(VisionModelUpdateDesk.autoKey, _auto);
    await prefs.setBool(VisionModelUpdateDesk.wifiKey, _wifiOnly);
    VisionModelUpdateDesk.instance.applyPrefs(auto: _auto, wifi: _wifiOnly);
  }

  Future<void> _updateNow() async {
    await _saveUpdatePrefs();
    final report = await VisionModelUpdateDesk.instance.request(manual: true);
    if (!mounted) return;
    setState(() => _note = report.messageAr);
  }

  Future<void> _open(OfficialResource resource) async {
    final result = await const ExternalLinkDesk().open(resource.page);
    if (!mounted) return;
    setState(() => _note = result.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenArrival(
      message: 'موارد الرؤية',
      controls: const ['افتح العدسة الحية', 'فتح صفحة الناشر'],
      body: 'صفحات الناشرين لا تثبّت نموذجاً. العدسة الحية مسار منفصل.',
      child: Scaffold(
      appBar: AppBar(title: const Text('موارد الرؤية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'هذه صفحات ناشرين. تعريف الكاميرا غير نموذج تفسير الصورة، وإطار LiteRT غير ملف النموذج. لا يُثبَّت ملف تنفيذي من هنا.',
          ),
          const SizedBox(height: 8),
          const Text(
            'الزر الطولي الكبير غير مثبت موضعه ولا وظيفته في هذا المستودع ولا في نسخة الواجهة المرجعية المفحوصة. لم يُركب زر بادعاء اتفاق. الحسم المطلوب: الموضع، والوظيفة الثابتة، وهل يبدأ الاستماع أم وصف المشهد.',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('تحديث نماذج الكاميرا تلقائياً'),
            subtitle: const Text('مفعّل ما لم توقفه. لا يعود وحده بعد الإيقاف.'),
            value: _auto,
            onChanged: (value) async {
              setState(() => _auto = value);
              await _saveUpdatePrefs();
            },
          ),
          SwitchListTile(
            title: const Text('النماذج الكبيرة عبر Wi-Fi فقط'),
            subtitle: const Text('بلا قياس للشبكة لا يبدأ التنزيل.'),
            value: _wifiOnly,
            onChanged: (value) async {
              setState(() => _wifiOnly = value);
              await _saveUpdatePrefs();
            },
          ),
          Semantics(
            button: true,
            label: 'حدّث ذكاء الكاميرا الآن',
            child: OutlinedButton(
              onPressed: _updateNow,
              child: const Text('حدّث ذكاء الكاميرا الآن'),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: 'افتح العدسة الحية',
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveSightScreen(profileId: widget.profileId),
                  ),
                );
              },
              icon: const Icon(Icons.videocam),
              label: const Text('افتح العدسة الحية'),
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, label: _note, child: Text(_note!)),
          ],
          for (final resource in OfficialResourceCatalog.vision)
            Card(
              child: ListTile(
                title: Text(resource.name),
                subtitle: Text(
                  '${resource.kindAr} — ${resource.publisher}\n'
                  '${resource.requirementAr}\n'
                  '${resource.noteAr}\n'
                  'آخر تحقق من الرابط: ${resource.checkedOn}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(resource),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
