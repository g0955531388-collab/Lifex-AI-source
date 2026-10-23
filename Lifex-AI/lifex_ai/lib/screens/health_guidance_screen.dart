/// =============================================================
/// Lifex-AI — الإرشاد الصحي
/// سؤال نصي أو صوتي. الإجابة من المرجع أو حدّ صريح. بلا فيديو مخترع.
/// =============================================================
library lifex_ai.screens.health_guidance_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/local_knowledge.dart';
import '../features/guidance/health_guidance_desk.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/voice_or_type_field.dart';

class HealthGuidanceScreen extends StatefulWidget {
  const HealthGuidanceScreen({
    super.key,
    this.profileId,
    this.seedQuestion,
    this.signalNoteAr,
  });

  final String? profileId;
  final String? seedQuestion;
  final String? signalNoteAr;

  @override
  State<HealthGuidanceScreen> createState() => _HealthGuidanceScreenState();
}

class _HealthGuidanceScreenState extends State<HealthGuidanceScreen> {
  final _log = GuidanceLog();
  final _question = TextEditingController();
  HealthGuidanceReply? _reply;

  @override
  void initState() {
    super.initState();
    final seed = widget.seedQuestion?.trim() ?? '';
    if (seed.isNotEmpty) _question.text = seed;
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final knowledge = context.read<LocalKnowledge>();
    final reply = HealthGuidanceDesk(knowledge: knowledge).answer(
      _question.text,
      signalNoteAr: widget.signalNoteAr,
    );
    final id = widget.profileId?.trim() ?? '';
    if (id.isNotEmpty) {
      _log.save(
        profileId: id,
        question: _question.text,
        answerAr: reply.answerAr,
      );
    }
    setState(() => _reply = reply);
    await VoiceEngine.instance.speak('${reply.answerAr}\n${reply.videoNoteAr}');
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply;
    return ScreenArrival(
      message:
          'الإرشاد الصحي مجاني على هذا الجهاز. ليس تشخيصاً. الفيديو يُعرض إن وُجد محلياً.',
      child: Scaffold(
        appBar: AppBar(title: const Text('الإرشاد والوقاية')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'الاستشارة الأساسية بلا أجر. لا وصفة ولا تشخيص قطعي. '
              'توليد فيديو خارجي غير موصول.',
            ),
            const SizedBox(height: 12),
            VoiceOrTypeField(controller: _question, label: 'السؤال'),
            FilledButton(
              onPressed: _ask,
              child: const Text('أجب من المرجع المحلي'),
            ),
            const SizedBox(height: 12),
            if (reply != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(reply.answerAr),
              ),
              const SizedBox(height: 8),
              Text(
                reply.sourceTitle == null
                    ? 'بلا عنوان مصدر مطابق.'
                    : 'المصدر المحلي: ${reply.sourceTitle}',
              ),
              const SizedBox(height: 8),
              Text(reply.videoNoteAr),
              if (reply.video != null) ...[
                const SizedBox(height: 8),
                Text('التفريغ: ${reply.video!.transcriptAr}'),
                FilledButton(
                  onPressed: () =>
                      VoiceEngine.instance.speak(reply.video!.transcriptAr),
                  child: const Text('اقرأ التفريغ'),
                ),
              ],
              if (_log.notes.isNotEmpty)
                Text('حُفظ ${_log.notes.length} في سجل هذه الجلسة للملف.'),
            ],
          ],
        ),
      ),
    );
  }
}
