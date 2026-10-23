/// =============================================================
/// Lifex-AI — حقل يُكتب أو يُملى
/// الاستماع عبر VoiceEngine القائم. الرفض يُقال ولا يُخزَّن سراً.
/// =============================================================
library lifex_ai.widgets.voice_or_type_field;

import 'package:flutter/material.dart';

import '../features/voice/voice_engine.dart';

class VoiceOrTypeField extends StatefulWidget {
  const VoiceOrTypeField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  State<VoiceOrTypeField> createState() => _VoiceOrTypeFieldState();
}

class _VoiceOrTypeFieldState extends State<VoiceOrTypeField> {
  bool _busy = false;

  Future<void> _listen() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await VoiceEngine.instance.listenFresh();
    if (!mounted) return;
    final heard = result.textResult?.trim() ?? '';
    if (result.success && heard.isNotEmpty) {
      widget.controller.text = heard;
      setState(() => _busy = false);
      return;
    }
    final message = result.errorMessageAr ??
        'لم يُلتقط كلام. يمكنك الكتابة. الميكروفون لا يبقى مفتوحاً.';
    setState(() => _busy = false);
    await VoiceEngine.instance.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              keyboardType: widget.keyboardType,
              decoration: InputDecoration(labelText: widget.label),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'إملاء ${widget.label}',
            child: IconButton(
              onPressed: _busy ? null : _listen,
              icon: const Icon(Icons.mic_none),
              tooltip: 'إملاء',
            ),
          ),
        ],
      ),
    );
  }
}
