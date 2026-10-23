/// أثر نصي لمسار الإطار. بلا صور ولا فيديو ولا بيانات صحية.
library lifex_ai.features.accessibility.blind_frame_trace;

class BlindFrameTrace {
  int received = 0;
  int delivered = 0;
  int classified = 0;
  int spoken = 0;
  final List<String> notes = [];
  final Set<int> _deliveredIds = {};
  final Set<int> _classifiedIds = {};
  final Set<int> _spokenIds = {};

  String opened(DateTime at) => _note(at, 0, 'فتح الكاميرا', true, '');

  String receive(DateTime at) {
    received++;
    if (received != 1) return '';
    return _note(at, 0, 'استلام', true, 'أول إطار');
  }

  String deliver(int sequence, DateTime at) {
    if (!_deliveredIds.add(sequence)) {
      return _note(at, sequence, 'تسليم', false, 'الإطار نفسه أُرسل من قبل');
    }
    delivered++;
    return _note(at, sequence, 'تسليم للمصنّف', true, '');
  }

  String classifierReturned({
    required int sequence,
    required DateTime at,
    required int elapsedMs,
    required bool ok,
    int accepted = 0,
    String top = '',
    String failure = '',
  }) {
    if (!_classifiedIds.add(sequence)) {
      return _note(
        at,
        sequence,
        'نتيجة المصنّف',
        false,
        'معالجة مكررة',
        elapsedMs: elapsedMs,
      );
    }
    if (!ok) {
      return _note(
        at,
        sequence,
        'نتيجة المصنّف',
        false,
        failure.isEmpty ? 'فشل بلا تفصيل' : failure,
        elapsedMs: elapsedMs,
      );
    }
    classified++;
    final name = top.trim().isEmpty ? 'فارغ' : top.trim();
    return _note(
      at,
      sequence,
      'نتيجة المصنّف',
      true,
      'مقبول=$accepted أعلى=$name',
      elapsedMs: elapsedMs,
    );
  }

  String ignoreLow(
    int sequence,
    DateTime at,
    String label,
    double confidence,
  ) {
    return _note(
      at,
      sequence,
      'تجاهل',
      false,
      '$label ثقة=${confidence.toStringAsFixed(2)} دون الحد',
    );
  }

  String skipRepeat(int sequence, DateTime at) {
    return _note(at, sequence, 'نطق', false, 'الوصف لم يتغير');
  }

  String reachedSpeech(int sequence, DateTime at) {
    if (!_spokenIds.add(sequence)) {
      return _note(at, sequence, 'نطق', false, 'الإطار نفسه وصل للنطق من قبل');
    }
    spoken++;
    return _note(at, sequence, 'نطق', true, 'الوصف العربي وصل إلى محرك النطق');
  }

  String fail(int sequence, DateTime at, String stage, String reason) {
    return _note(at, sequence, stage, false, reason);
  }

  String stopped(DateTime at, String reason) {
    return _note(at, 0, 'إيقاف التدفق', true, reason);
  }

  String _note(
    DateTime at,
    int sequence,
    String stage,
    bool ok,
    String detail, {
    int? elapsedMs,
  }) {
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final clock =
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.'
        '${local.millisecond.toString().padLeft(3, '0')}';
    final extra = [
      if (detail.isNotEmpty) detail,
      if (elapsedMs != null) '${elapsedMs}ms',
    ].join(' ');
    final line =
        '$clock #$sequence $stage ${ok ? 'نجح' : 'فشل'}${extra.isEmpty ? '' : ' $extra'}';
    notes.add(line);
    if (notes.length > 12) notes.removeAt(0);
    return line;
  }

  String statusAr() =>
      'إطارات مستلمة: $received. سُلّمت للمصنّف: $delivered. '
      'أعاد المصنّف نتيجة: $classified. وصلت للنطق: $spoken.';
}
