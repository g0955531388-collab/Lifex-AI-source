/// =============================================================
/// Lifex-AI — المكوّنات المشتركة
/// الملف: voice_fill_button.dart
/// ملء حقل بالصوت بعد موافقة الميكروفون، مع إشارة استماع واضحة.
/// =============================================================
library lifex_ai.widgets.voice_fill_button;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/permission_transparency.dart';
import '../features/voice/voice_engine.dart';

class VoiceFillButton extends StatefulWidget {
  const VoiceFillButton({super.key, required this.onText});

  final void Function(String text) onText;

  @override
  State<VoiceFillButton> createState() => _VoiceFillButtonState();
}

class _VoiceFillButtonState extends State<VoiceFillButton> {
  bool _busy = false;

  Future<void> _listen() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إذن الميكروفون'),
        content: const Text(
          'لملء الحقل بالصوت وأنت تضغط. ليس تجسساً في الخلفية ولا قراءة رسائل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.microphone,
      granted: true,
    );
    PermissionTransparencyManager.instance
        .useIfGranted(LifexSensitivePermission.microphone);
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(content: Text('أستمع وأسجّل الآن...')),
    );
    final result = await VoiceEngine.instance.listenFresh();
    if (!mounted) return;
    setState(() => _busy = false);
    final text = result.textResult?.trim() ?? '';
    if (text.isNotEmpty) {
      widget.onText(text);
      messenger?.showSnackBar(SnackBar(content: Text('سُجّل: $text')));
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          result.errorMessageAr ?? 'لم يُسمع كلام. لا أملأ الحقل بدون صوت.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _busy ? 'جارٍ الاستماع' : 'ملء بالصوت',
      onPressed: _busy ? null : _listen,
      icon: Icon(
        _busy ? Icons.hearing : Icons.mic,
        color: _busy ? Colors.red : null,
      ),
    );
  }
}
