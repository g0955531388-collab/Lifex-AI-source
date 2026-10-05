/// =============================================================
/// Lifex-AI — مركز الأجهزة (واجهة تطبيق)
/// الملف: device_center_screen.dart
/// يعرض حالة السلسلة ولا يدّعي دعم كل الهاردوير.
/// =============================================================
library lifex_ai.screens.device_center_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/devices/lifex_device_runtime.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';

class DeviceCenterScreen extends StatefulWidget {
  const DeviceCenterScreen({super.key});

  @override
  State<DeviceCenterScreen> createState() => _DeviceCenterScreenState();
}

class _DeviceCenterScreenState extends State<DeviceCenterScreen> {
  String _lastSpoken = '';
  bool _busy = false;

  Future<void> _speak(DeviceVoiceOutcome o) async {
    setState(() => _lastSpoken = o.spokenAr);
    announceForScreenReader(context, o.spokenAr);
    await VoiceEngine.instance.speak(o.spokenAr);
  }

  Future<void> _run(Future<DeviceVoiceOutcome> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted) return;
      await _speak(outcome);
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = context.read<LifexDeviceRuntime>();
    final tiles = runtime.dashboard();
    final transports = runtime.transportMatrix();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الأجهزة'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            header: true,
            child: const Text(
              'سلسلة Lifex: اكتشاف → تعريف → قدرات → سائق → بروتوكول → جلسة → أمر → تحقق',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          LiveAnnouncingText(
            message: _lastSpoken.isEmpty
                ? 'مركز الأجهزة جاهز. المحاكاة متاحة. العتاد الحقيقي يحتاج Adapter وإذن Android.'
                : _lastSpoken,
          ),
          const SizedBox(height: 16),
          AccessibleActionButton(
            icon: Icons.search,
            label: 'اكتشف الأجهزة',
            semanticHint: 'يشغّل اكتشاف الأجهزة الافتراضية والمتاحة',
            onTap: _busy
                ? null
                : () => _run(() async {
                      final list = await runtime.discover();
                      return DeviceVoiceOutcome(
                        spokenAr:
                            'عُثر على ${list.length} جهازاً في الاكتشاف. ليست كلها عتاداً حقيقياً.',
                        spokenEn: 'Found ${list.length} devices in discovery.',
                        ok: true,
                      );
                    }),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.accessible,
            label: 'أظهر الكرسي',
            semanticHint: 'يرفق كرسي Lifex المحاكى عبر السلسلة الكاملة',
            onTap: _busy
                ? null
                : () => _run(runtime.attachSimulatedWheelchair),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.info_outline,
            label: 'حالة الكرسي',
            semanticHint: 'يقرأ حالة الكرسي بصوت مسموع',
            onTap: _busy ? null : () => _run(runtime.wheelchairStatusSpoken),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.battery_full,
            label: 'بطارية الكرسي',
            semanticHint: 'يقرأ نسبة بطارية المحاكاة',
            onTap: _busy
                ? null
                : () => _run(() => runtime.runWheelchairAction('READ_BATTERY')),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.arrow_upward,
            label: 'تقدم (مع تأكيد)',
            semanticHint: 'أمر حركة للأمام عبر مركز التحكم مع سياسة سلامة',
            onTap: _busy
                ? null
                : () => _run(
                      () => runtime.runWheelchairAction(
                        'MOVE_FORWARD',
                        userConfirmed: false,
                      ),
                    ),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.check_circle_outline,
            label: 'أكّد الحركة',
            semanticHint: 'يؤكد أمر الحركة المعلّق',
            onTap: _busy ? null : () => _run(runtime.confirmPendingMotion),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.stop_circle_outlined,
            label: 'توقف',
            semanticHint: 'إيقاف فوري بأولوية عالية',
            isUrgent: true,
            onTap: _busy
                ? null
                : () => _run(() => runtime.runWheelchairAction('STOP')),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.warning_amber,
            label: 'إيقاف طوارئ',
            semanticHint: 'إيقاف طوارئ بأولوية قصوى دون انتظار تأكيد',
            isUrgent: true,
            onTap: _busy
                ? null
                : () =>
                    _run(() => runtime.runWheelchairAction('EMERGENCY_STOP')),
          ),
          const SizedBox(height: 24),
          const Text(
            'الأجهزة المُدارة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (tiles.isEmpty)
            const ListTile(title: Text('لا أجهزة مرفقة بعد'))
          else
            ...tiles.map(
              (t) => ListTile(
                title: Text(t.title),
                subtitle: Text(t.statusLabel),
                leading: Icon(
                  t.streaming ? Icons.stream : Icons.devices,
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'قدرات النقل (صدق Android)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          ...transports.map(
            (t) => ListTile(
              title: Text(t.transport),
              subtitle: Text('${t.support.name}: ${t.noteAr}'),
            ),
          ),
        ],
      ),
    );
  }
}
