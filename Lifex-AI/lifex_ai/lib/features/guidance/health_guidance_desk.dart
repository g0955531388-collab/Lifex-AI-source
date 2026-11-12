/// =============================================================
/// Lifex-AI — الإرشاد الصحي والوقاية
/// إجابة من المرجع المحلي أو حدّ صريح. ليست تشخيصاً ولا وصفة.
/// الاستشارة الأساسية بلا أجر. توليد الفيديو غير موصول.
/// =============================================================
library lifex_ai.features.guidance.health_guidance_desk;

import '../../core/local_knowledge.dart';

class EducationClip {
  const EducationClip({
    required this.id,
    required this.titleAr,
    required this.producerAr,
    required this.transcriptAr,
    this.updatedOn,
    this.localAsset,
  });

  final String id;
  final String titleAr;
  final String producerAr;
  final String transcriptAr;
  final String? updatedOn;
  final String? localAsset;
}

class HealthGuidanceReply {
  const HealthGuidanceReply({
    required this.answerAr,
    required this.sourceTitle,
    required this.matchedReference,
    required this.video,
    required this.videoNoteAr,
  });

  final String answerAr;
  final String? sourceTitle;
  final bool matchedReference;
  final EducationClip? video;
  final String videoNoteAr;

  static const diagnosisAllowed = false;
  static const prescriptionAllowed = false;
  static const feeApplies = false;
  static const remoteVideoGenerationAllowed = false;
}

class GuidanceNote {
  const GuidanceNote({
    required this.profileId,
    required this.question,
    required this.answerAr,
    required this.at,
  });

  final String profileId;
  final String question;
  final String answerAr;
  final DateTime at;
}

class GuidanceLog {
  final List<GuidanceNote> notes = [];

  bool save({
    required String profileId,
    required String question,
    required String answerAr,
    DateTime? at,
  }) {
    final id = profileId.trim();
    final q = question.trim();
    if (id.isEmpty || q.isEmpty) return false;
    notes.add(
      GuidanceNote(
        profileId: id,
        question: q,
        answerAr: answerAr,
        at: at ?? DateTime.now(),
      ),
    );
    return true;
  }
}

class HealthGuidanceDesk {
  const HealthGuidanceDesk({
    this.knowledge,
    this.clips = const [],
  });

  final LocalKnowledge? knowledge;
  final List<EducationClip> clips;

  HealthGuidanceReply answer(
    String question, {
    String? signalNoteAr,
  }) {
    final q = question.trim();
    if (q.isEmpty) {
      return const HealthGuidanceReply(
        answerAr: 'اكتب السؤال أو قاله. لن أخترع موضوعاً.',
        sourceTitle: null,
        matchedReference: false,
        video: null,
        videoNoteAr: 'لا فيديو قبل وجود سؤال.',
      );
    }
    final hits = knowledge?.search(q) ?? const <KnowledgeHit>[];
    final hit = hits.isEmpty ? null : hits.first;
    final clip = _clipFor(q);
    final videoNote = clip == null
        ? 'لا فيديو تعليمي مطابق في هذا الجهاز. تبقى الإجابة نصاً وصوتاً. '
            'توليد فيديو خارجي غير موصول.'
        : 'فيديو محلي: ${clip.titleAr}. الجهة: ${clip.producerAr}. '
            '${clip.updatedOn ?? 'بلا تاريخ'}';
    final body = hit == null
        ? 'لم أجد مطابقة في المرجع المحلي لـ "$q". '
            'لن أخمّن تشخيصاً ولن أصف دواءً. '
            'وقاية عامة: نظافة اليدين، والابتعاد عن المخالطة عند أعراض تنفسية، '
            'ومراجعة جهة صحية إذا ضاق النفس أو ساء الوضع بسرعة.'
        : 'من المرجع المحلي (${hit.kindAr}): ${hit.titleAr}. ${hit.detailAr} '
            'هذه معلومة مرجعية وليست تشخيصاً ولا وصفة.';
    final signal = (signalNoteAr ?? '').trim();
    final prefix = signal.isEmpty ? '' : 'إشارة الرصد: $signal\n';
    return HealthGuidanceReply(
      answerAr: '$prefix$body\nالاستشارة الأساسية بلا أجر على هذا الجهاز. '
          'ليست تشخيصاً.',
      sourceTitle: hit?.titleAr,
      matchedReference: hit != null,
      video: clip,
      videoNoteAr: videoNote,
    );
  }

  EducationClip? _clipFor(String question) {
    final q = question.toLowerCase();
    for (final clip in clips) {
      final title = clip.titleAr.toLowerCase();
      if (title.isNotEmpty && (title.contains(q) || q.contains(title))) {
        return clip;
      }
    }
    return null;
  }
}
