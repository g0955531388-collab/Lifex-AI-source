/// كلمة في النص المقروء قد تشير إلى نوع وثيقة. الكلمة لا تثبت النوع
/// ولا تفسّر أشعة أو مخططاً ولا تشخّص.
library lifex_ai.features.camera_ai.medical.medical_image_analyzer;

enum MedicalImagingModality {
  xray,
  ultrasound,
  ctScan,
  mri,
  ecg,
  eeg,
  emg,
  labReport,
  prescription,
  unknown,
}

class MedicalImageAnalysisResult {
  const MedicalImageAnalysisResult({
    required this.modality,
    required this.extractedText,
    required this.structuredFindings,
    required this.summaryAr,
    required this.needsDoctorReview,
  });

  final MedicalImagingModality modality;
  final String extractedText;
  final Map<String, String> structuredFindings;
  final String summaryAr;
  final bool needsDoctorReview;
}

class MedicalImageAnalyzer {
  const MedicalImageAnalyzer();

  static const _modalityKeywords = <MedicalImagingModality, List<String>>{
    MedicalImagingModality.xray: ['x-ray', 'xray', 'radiograph', 'أشعة'],
    MedicalImagingModality.ultrasound: ['ultrasound', 'sonograph', 'إيكو'],
    MedicalImagingModality.ctScan: ['ct scan', 'computed tomography', 'طبقي'],
    MedicalImagingModality.mri: ['mri', 'magnetic resonance', 'رنين'],
    MedicalImagingModality.ecg: ['ecg', 'ekg', 'electrocardiogram', 'تخطيط القلب'],
    MedicalImagingModality.eeg: ['eeg', 'electroencephalogram', 'تخطيط الدماغ'],
    MedicalImagingModality.emg: ['emg', 'electromyography'],
    MedicalImagingModality.labReport: ['cbc', 'lab report', 'مخبر', 'تحاليل'],
    MedicalImagingModality.prescription: ['prescription', 'وصفة'],
  };

  static const _reviewKeywords = [
    'acute',
    'critical',
    'urgent',
    'malignant',
    'tumor',
    'حاد',
    'حرج',
    'ورم',
    'خبيث',
  ];

  MedicalImageAnalysisResult analyzeReadText(String text) {
    final lower = text.toLowerCase();
    final modality = _classify(lower);
    final findings = _values(text);
    final needsReview = _reviewKeywords.any(lower.contains);
    final buffer = StringBuffer(
      'تخمين غير مؤكد من كلمة في النص: ${_modalityAr(modality)}. '
      'ليس تفسيراً للصورة ولا تشخيصاً. ',
    );
    if (findings.isNotEmpty) {
      buffer.write('أرقام ظهرت بجانب رموز في النص: ');
      findings.forEach((key, value) => buffer.write('$key = $value، '));
    }
    if (needsReview) {
      buffer.write(
        'ظهرت كلمة من قائمة المراجعة داخل النص المقروء. هذا ليس حكماً على الصورة.',
      );
    }
    return MedicalImageAnalysisResult(
      modality: modality,
      extractedText: text,
      structuredFindings: findings,
      summaryAr: buffer.toString().trim(),
      needsDoctorReview: needsReview,
    );
  }

  MedicalImagingModality _classify(String lowerText) {
    var best = MedicalImagingModality.unknown;
    var bestScore = 0;
    for (final entry in _modalityKeywords.entries) {
      var score = 0;
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword.toLowerCase())) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best;
  }

  Map<String, String> _values(String text) {
    final out = <String, String>{};
    final pattern = RegExp(
      r'\b(WBC|RBC|HGB|HCT|PLT|GLU|CRE|ALT|AST|CRP|SpO2)\b\s*[:=]?\s*([0-9]+\.?[0-9]*)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(text)) {
      out[match.group(1)!.toUpperCase()] = match.group(2)!;
    }
    return out;
  }

  static String _modalityAr(MedicalImagingModality modality) => {
        MedicalImagingModality.xray: 'كلمة تشير إلى أشعة',
        MedicalImagingModality.ultrasound: 'كلمة تشير إلى إيكو',
        MedicalImagingModality.ctScan: 'كلمة تشير إلى طبقي',
        MedicalImagingModality.mri: 'كلمة تشير إلى رنين',
        MedicalImagingModality.ecg: 'كلمة تشير إلى مخطط قلب',
        MedicalImagingModality.eeg: 'كلمة تشير إلى مخطط دماغ',
        MedicalImagingModality.emg: 'كلمة تشير إلى مخطط عضلات',
        MedicalImagingModality.labReport: 'كلمة تشير إلى تقرير مخبر',
        MedicalImagingModality.prescription: 'كلمة تشير إلى وصفة',
        MedicalImagingModality.unknown: 'unknown',
      }[modality]!;
}
