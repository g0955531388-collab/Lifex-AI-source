/// قراءة محلية بالحروف اللاتينية المطبوعة، ثم Cloud Vision إن وُجد مفتاح
/// والنص المحلي فارغ أو فيه حروف عربية. النص السحابي قد يخطئ.
/// الخط اليدوي ليس قدرة مثبتة على هذا الجهاز.
library lifex_ai.features.camera_ai.reading.universal_text_reader;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/agent/adapters/mlkit_ocr_extractor.dart';
import '../../../core/config/app_secrets.dart';

class UniversalReadResult {
  const UniversalReadResult({
    required this.text,
    required this.source,
    required this.detectedLanguageNoteAr,
    this.wasCloudFallbackUsed = false,
  });

  final String text;
  final String source;
  final String detectedLanguageNoteAr;
  final bool wasCloudFallbackUsed;

  bool get isEmpty => text.trim().isEmpty;
}

abstract class CloudOcrClient {
  Future<String?> readTextFromImageBase64(String base64Jpeg);
}

/// Cloud Vision عند وجود مفتاح غير فارغ. المفتاح الفارغ لا يفتح الشبكة.
class GoogleCloudVisionClient implements CloudOcrClient {
  GoogleCloudVisionClient({http.Client? httpClient}) : _http = httpClient;

  final http.Client? _http;

  @override
  Future<String?> readTextFromImageBase64(String base64Jpeg) async {
    final apiKey = AppSecrets.googleVisionApiKey;
    if (apiKey.isEmpty || base64Jpeg.isEmpty) return null;
    try {
      final sender = _http ?? http.Client();
      final closeSender = _http == null;
      try {
        final response = await sender
            .post(
              Uri.parse(
                'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requests': [
                  {
                    'image': {'content': base64Jpeg},
                    'features': [
                      {'type': 'TEXT_DETECTION'},
                      {'type': 'DOCUMENT_TEXT_DETECTION'},
                    ],
                  }
                ],
              }),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) return null;
        final data = jsonDecode(response.body);
        if (data is! Map) return null;
        final responses = data['responses'];
        if (responses is! List || responses.isEmpty) return null;
        final first = responses.first;
        if (first is! Map) return null;
        final text = first['fullTextAnnotation'];
        if (text is! Map) return null;
        final value = text['text'];
        if (value is! String) return null;
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      } finally {
        if (closeSender) sender.close();
      }
    } catch (_) {
      return null;
    }
  }
}

class UniversalTextReader {
  UniversalTextReader({
    CloudOcrClient? cloudClient,
    Future<String> Function(List<int> imageBytes)? localReader,
    this.cloudEnabled,
  })  : _cloud = cloudClient ?? GoogleCloudVisionClient(),
        _local = localReader ?? _deviceLatin;

  final CloudOcrClient _cloud;
  final Future<String> Function(List<int> imageBytes) _local;

  /// null يتبع وجود المفتاح. الاختبار يمرّر true مع عميل بديل.
  final bool? cloudEnabled;

  static final _arabicPattern = RegExp(r'[\u0600-\u06FF]');

  static Future<String> _deviceLatin(List<int> imageBytes) {
    return const MlKitOcrExtractor().extractText(imageBytes);
  }

  Future<UniversalReadResult> read(List<int> imageBytes) async {
    final localText = await _local(imageBytes);
    final wantsCloud = _arabicPattern.hasMatch(localText) ||
        localText.trim().length < 3;
    final allowCloud = cloudEnabled ?? AppSecrets.googleVisionApiKey.isNotEmpty;
    if (wantsCloud && allowCloud) {
      final cloudText =
          await _cloud.readTextFromImageBase64(base64Encode(imageBytes));
      if (cloudText != null &&
          cloudText.trim().length > localText.trim().length) {
        return UniversalReadResult(
          text: cloudText.trim(),
          source: 'cloud',
          detectedLanguageNoteAr:
              'النص جاء من Cloud Vision وقد يخطئ. ليس تأكيداً لقراءة العربية أو الخط اليدوي.',
          wasCloudFallbackUsed: true,
        );
      }
    }
    return UniversalReadResult(
      text: localText,
      source: 'on-device',
      detectedLanguageNoteAr: _arabicPattern.hasMatch(localText)
          ? 'ظهرت حروف عربية. القارئ المحلي يقرأ اللاتيني المطبوع. '
              'بلا مفتاح Cloud Vision تبقى القراءة ناقصة.'
          : 'قراءة محلية للحروف اللاتينية المطبوعة.',
    );
  }
}
