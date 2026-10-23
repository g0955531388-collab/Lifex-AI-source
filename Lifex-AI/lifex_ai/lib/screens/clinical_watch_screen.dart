/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: clinical_watch_screen.dart
/// مراقبة اختيارية بإشعار ظاهر. ليست تجسساً وليست أرشيفاً.
/// =============================================================
library lifex_ai.screens.clinical_watch_screen;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/permission_transparency.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/clinical_watch_bridge.dart';
import '../features/voice/clinical_watch_command_relay.dart';
import '../features/voice/clinical_watch_policy.dart';
import '../widgets/honesty_banner.dart';
import 'live_sight_screen.dart';
import 'permission_transparency_screen.dart';

class ClinicalWatchScreen extends StatefulWidget {
  const ClinicalWatchScreen({super.key});

  @override
  State<ClinicalWatchScreen> createState() => _ClinicalWatchScreenState();
}

class _ClinicalWatchScreenState extends State<ClinicalWatchScreen> {
  static const _policy = ClinicalWatchPolicy();
  bool _optIn = false;
  bool _cameraNotice = false;
  bool _noticeVisible = false;
  bool _busy = false;
  String _status = 'المراقبة متوقفة. لا ميكروفون في الخلفية حتى توافق ويظهر إشعار.';

  Future<void> _start() async {
    if (_busy) return;
    if (!_optIn) {
      setState(() => _status = 'بدون موافقتك الظاهرة لا يبدأ الإشعار ولا الاستماع.');
      return;
    }
    setState(() => _busy = true);
    try {
      final micOk = await _consent(
        LifexSensitivePermission.microphone,
        Permission.microphone,
        title: 'الميكروفون للمراقبة الصحية',
        body:
            'يُستخدم مع إشعار نظام دائم يمكنك إيقافه فوراً. ليس تسجيلاً خفياً ولا إرسالاً لخادم. '
            'تصنيف التنفس أو السقوط لا يُعلن حتى يُربط محرك معتمد.',
      );
      if (!micOk) {
        setState(() => _status = 'بدون إذن الميكروفون لا تُعلن المراقبة الصوتية.');
        return;
      }
      if (_cameraNotice) {
        final camOk = await _consent(
          LifexSensitivePermission.camera,
          Permission.camera,
          title: 'العدسة بإشعار ظاهر',
          body:
              'تفعيل نوع الكاميرا في الإشعار لا يحفظ صوراً ولا يفتح عدسة خفية. '
              'البث الحي يبقى على شاشته بعد موافقة ثانية.',
        );
        if (!camOk) {
          setState(() => _status = 'رفض العدسة. يمكنك بدء الإشعار الصوتي فقط.');
          return;
        }
      }
      await Permission.notification.request();
      final message = await ClinicalWatchBridge.instance.start(
        cameraLiveNoStore: _cameraNotice,
      );
      final noticeUp = !message.contains('لا توجد خدمة نظام') &&
          !message.startsWith('تعذّر');
      final allowed = _policy.mayListenAwayFromScreen(
        userOptIn: true,
        persistentNoticeVisible: noticeUp,
      );
      setState(() {
        _noticeVisible = allowed;
        _status = allowed
            ? '$message\n${_policy.engineHonestyAr(ClinicalWatchPurpose.commands)}'
            : message;
      });
      if (allowed) ClinicalWatchCommandRelay.instance.start();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await ClinicalWatchCommandRelay.instance.stop();
    await ClinicalWatchBridge.instance.stop();
    if (!mounted) return;
    setState(() {
      _noticeVisible = false;
      _status = 'أُوقف إشعار المراقبة من التطبيق. إن بقي في الشريط أوقفه من زر الإشعار.';
    });
  }

  Future<bool> _consent(
    LifexSensitivePermission kind,
    Permission runtime, {
    required String title,
    required String body,
  }) async {
    if (PermissionTransparencyManager.instance.isGranted(kind) &&
        await runtime.isGranted) {
      return true;
    }
    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أوافق لهذه الوظيفة'),
          ),
        ],
      ),
    );
    PermissionTransparencyManager.instance.decide(
      permission: kind,
      granted: agreed == true,
    );
    if (agreed != true) return false;
    final status = await runtime.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراقبة سريرية ظاهرة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HonestyBanner(messageAr: _policy.storeAndLegalJustificationAr()),
          const SizedBox(height: 8),
          const HonestyBanner(
            messageAr:
                'مع الإشعار الدائم يستمر الاستماع للأوامر في الخلفية لحماية من يستخدم هذا الهاتف. '
                'إيقاف الإشعار أو انتهاء العملية يوقف الميكروفون. '
                'لا أختلق سقوطاً أو تنفساً، ولا أتصل بأحد من تلقاء نفسي.',
          ),
          SwitchListTile(
            title: const Text('أوافق على مراقبة ظاهرة بجانب المريض'),
            subtitle: const Text('يمكن إيقافها فوراً من الإشعار أو من هنا'),
            value: _optIn,
            onChanged: (value) => setState(() => _optIn = value),
          ),
          SwitchListTile(
            title: const Text('إعلان العدسة في الإشعار (بلا حفظ إطار)'),
            subtitle: Text(_policy.engineHonestyAr(ClinicalWatchPurpose.bedsideCamera)),
            value: _cameraNotice,
            onChanged: !_optIn
                ? null
                : (value) => setState(() => _cameraNotice = value),
          ),
          for (final purpose in ClinicalWatchPurpose.values)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(_policy.purposeAr(purpose)),
              subtitle: Text(_policy.engineHonestyAr(purpose)),
            ),
          FilledButton.icon(
            onPressed: _busy || !_optIn ? null : _start,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(_busy ? 'يبدأ الإشعار...' : 'بدء الإشعار الظاهر'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _noticeVisible || _optIn ? _stop : null,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('إيقاف المراقبة'),
          ),
          const SizedBox(height: 12),
          Text(_status),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('البث الحي على الشاشة'),
            subtitle: const Text('العدسة ظاهرة. لا أرشيف'),
            onTap: () {
              final id =
                  context.read<ActiveProfileController>().activeProfileId;
              if (id == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LiveSightScreen(profileId: id)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('شفافية الصلاحيات'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PermissionTransparencyScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
