/// =============================================================
/// Lifex-AI — القياسات الحيوية
/// الملف: manual_vital_board.dart
/// لوحة قياسات يدوية. الأرقام من المستخدم أو جهازه، وليست من بكسل
/// صورة ولا من قيم ثابتة (37 / 98 / 72 / 120/80). لون البول ملاحظة
/// تُدخل، لا تحليل مخبري. نغمة MIDI تُحسب من النبض المدخل دون منفذ.
/// =============================================================
library lifex_ai.features.vitals.manual_vital_board;

import 'dart:math' as math;

class ManualVitalDraft {
  const ManualVitalDraft({
    this.tempC,
    this.oxygenPercent,
    this.pulseBpm,
    this.bloodPressure,
    this.urineColorNote,
    this.urineFoamNote,
    this.urineClarityNote,
  });

  final double? tempC;
  final int? oxygenPercent;
  final int? pulseBpm;
  final String? bloodPressure;
  final String? urineColorNote;
  final String? urineFoamNote;
  final String? urineClarityNote;

  bool get hasNumericValue =>
      tempC != null ||
      oxygenPercent != null ||
      pulseBpm != null ||
      (bloodPressure != null && bloodPressure!.trim().isNotEmpty);

  bool get hasUrineNote => UrineColorNote.linesFrom(this).isNotEmpty;

  bool get hasAnyValue => hasNumericValue || hasUrineNote;
}

class ManualVitalScore {
  const ManualVitalScore({
    required this.points,
    required this.statusAr,
    required this.messageAr,
    required this.completeEnough,
  });

  final int points;
  final String statusAr;
  final String messageAr;
  final bool completeEnough;
}

/// قواعد محلية على أرقام أدخلها المستخدم. ليست تشخيصاً.
class ManualVitalPolicy {
  const ManualVitalPolicy();

  static const refuseBitmapAnalysisAr =
      'لن أستخرج حرارة أو أكسجين أو نبضاً أو لون بول من صورة. '
      'أدخل الأرقام من ميزانك أو مقياس الأكسجين أو المختبر.';

  static const neverInventAr =
      'لا تُملأ القيم الناقصة بـ 37 أو 98 أو 72 أو 120/80.';

  ManualVitalScore score(ManualVitalDraft draft) {
    if (!draft.hasAnyValue) {
      return const ManualVitalScore(
        points: 0,
        statusAr: 'لا أرقام بعد',
        messageAr:
            'لم تُدخل قياساً. لن أعلن استقراراً ولن أخترع قراءة من كاميرا.',
        completeEnough: false,
      );
    }

    var points = 0;
    final notes = <String>[];
    if (draft.oxygenPercent != null) {
      if (draft.oxygenPercent! < 94) {
        points += 40;
        notes.add('الأكسجين الذي أدخلته أقل من 94.');
      } else {
        notes.add('الأكسجين الذي أدخلته لا يتجاوز عتبة التنبيه المحلية.');
      }
    }
    if (draft.tempC != null) {
      if (draft.tempC! > 38.5) {
        points += 30;
        notes.add('الحرارة التي أدخلتها أعلى من 38.5.');
      } else {
        notes.add('الحرارة التي أدخلتها لا تتجاوز عتبة التنبيه المحلية.');
      }
    }
    if (draft.pulseBpm != null) {
      notes.add('النبض المسجّل ${draft.pulseBpm} — ليس من حسّاس مربوط.');
    }
    if (draft.bloodPressure != null && draft.bloodPressure!.trim().isNotEmpty) {
      notes.add('الضغط كما كتبته: ${draft.bloodPressure!.trim()}.');
    }
    final urineLines = UrineColorNote.linesFrom(draft);
    if (!draft.hasNumericValue) {
      return ManualVitalScore(
        points: 0,
        statusAr: 'ملاحظة',
        messageAr:
            '${urineLines.join(' ')} هذه ملاحظات وليست نتيجة تحليل.',
        completeEnough: true,
      );
    }

    points = points.clamp(0, 100);
    final alert = points > 50;
    final urineTail =
        urineLines.isEmpty ? '' : ' ${urineLines.join(' ')}';
    return ManualVitalScore(
      points: points,
      statusAr: alert
          ? 'تنبيه من الأرقام التي أدخلتها'
          : 'لا عتبة محلية على الأرقام المكتملة',
      messageAr:
          '${notes.join(' ')}$urineTail العداد المحلي $points من 100 على الأرقام التي أدخلتها فقط. ليست تشخيصاً ولا نتيجة مختبر.',
      completeEnough: true,
    );
  }
}

class UrineColorNote {
  const UrineColorNote._();

  static const none = 'لم يُدخل';
  static const options = [
    none,
    'فاتح',
    'أصفر',
    'داكن',
    'محمر',
    'أخرى كما أصفها',
  ];

  static const honestyAr =
      'لون البول والرغوة والوضوح ملاحظات تدخلها أنت. ليست تحليلاً مخبرياً ولا قراءة من بكسل الصورة.';

  static String lineAr(String color) =>
      'ملاحظة لون البول: $color. ليست نتيجة تحليل.';

  static String foamLineAr(String foam) =>
      'ملاحظة الرغوة: ${foam.trim()}. ليست نتيجة تحليل.';

  static String clarityLineAr(String clarity) =>
      'ملاحظة الوضوح: ${clarity.trim()}. ليست نتيجة تحليل.';

  static List<String> linesFrom(ManualVitalDraft draft) {
    final lines = <String>[];
    final color = draft.urineColorNote?.trim() ?? '';
    if (color.isNotEmpty && color != none) {
      lines.add(lineAr(color));
    }
    final foam = draft.urineFoamNote?.trim() ?? '';
    if (foam.isNotEmpty) lines.add(foamLineAr(foam));
    final clarity = draft.urineClarityNote?.trim() ?? '';
    if (clarity.isNotEmpty) lines.add(clarityLineAr(clarity));
    return lines;
  }
}

/// حساب نغمة من النبض المدخل. المنفذ غير مربوط حتى يوجد MIDI حقيقي.
class MidiPulseCue {
  const MidiPulseCue({this.portBound = false});

  final bool portBound;

  int noteForBpm(int bpm) {
    if (bpm <= 0) return 0;
    final raw = 69 + (12 * (math.log(bpm / 60) / math.ln2));
    return raw.truncate().clamp(0, 127);
  }

  String lineAr(int bpm) {
    final note = noteForBpm(bpm);
    if (portBound) {
      return 'نغمة MIDI رقم $note من نبض $bpm الذي أدخلته.';
    }
    return 'نغمة MIDI رقم $note محسوبة من نبض $bpm الذي أدخلته. '
        'لا منفذ MIDI مربوط على هذا الجهاز.';
  }
}
