/// =============================================================
/// Lifex-AI — AES-256-GCM لـ HealthObservation at-rest
/// LIFEXHOB1 = legacy بلا key id
/// LIFEXHOB2 = مع key identifier
/// =============================================================
library lifex_ai.core.health_data.health_observation_cipher;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// فشل سلامة/تفكيك ciphertext — لا يُترجم إلى بيانات صحية صالحة.
class HealthObservationCipherException implements Exception {
  HealthObservationCipherException(this.message);
  final String message;

  @override
  String toString() => 'HealthObservationCipherException: $message';
}

/// مغلف مفكوك — metadata فقط بلا مفتاح.
class HealthObservationCipherEnvelope {
  const HealthObservationCipherEnvelope({
    required this.format,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    this.keyId,
  });

  final String format;
  final String? keyId;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  bool get isLegacyHob1 => format == AesGcmHealthObservationCipher.formatHob1;
}

/// تشفير/فك AES-256-GCM.
class AesGcmHealthObservationCipher {
  AesGcmHealthObservationCipher({AesGcm? algorithm})
      : _algorithm = algorithm ?? AesGcm.with256bits();

  static const algorithmId = 'AES-256-GCM';
  static const formatHob1 = 'LIFEXHOB1';
  static const formatHob2 = 'LIFEXHOB2';

  /// التوافق الخلفي.
  static const envelopeVersion = formatHob1;

  final AesGcm _algorithm;

  Future<String> encrypt({
    required String plaintext,
    required Uint8List keyBytes,
    required String keyId,
  }) async {
    if (keyBytes.length != 32) {
      throw HealthObservationCipherException('AES-256 key must be 32 bytes');
    }
    if (keyId.trim().isEmpty || keyId.contains('.')) {
      throw HealthObservationCipherException('Invalid keyId for envelope');
    }
    final secretKey = SecretKey(keyBytes);
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );
    final nonce = base64Url.encode(box.nonce);
    final cipherText = base64Url.encode(box.cipherText);
    final mac = base64Url.encode(box.mac.bytes);
    return '$formatHob2.$keyId.$nonce.$cipherText.$mac';
  }

  HealthObservationCipherEnvelope parse(String envelope) {
    final parts = envelope.trim().split('.');
    if (parts.isEmpty) {
      throw HealthObservationCipherException('Empty ciphertext envelope');
    }
    final format = parts[0];
    if (format == formatHob2) {
      if (parts.length != 5) {
        throw HealthObservationCipherException(
          'Unrecognized or tampered LIFEXHOB2 envelope',
        );
      }
      try {
        return HealthObservationCipherEnvelope(
          format: formatHob2,
          keyId: parts[1],
          nonce: base64Url.decode(parts[2]),
          cipherText: base64Url.decode(parts[3]),
          mac: base64Url.decode(parts[4]),
        );
      } catch (e) {
        throw HealthObservationCipherException(
          'Tampered LIFEXHOB2 envelope encoding: $e',
        );
      }
    }
    if (format == formatHob1) {
      if (parts.length != 4) {
        throw HealthObservationCipherException(
          'Unrecognized or tampered LIFEXHOB1 envelope',
        );
      }
      try {
        return HealthObservationCipherEnvelope(
          format: formatHob1,
          keyId: null,
          nonce: base64Url.decode(parts[1]),
          cipherText: base64Url.decode(parts[2]),
          mac: base64Url.decode(parts[3]),
        );
      } catch (e) {
        throw HealthObservationCipherException(
          'Tampered LIFEXHOB1 envelope encoding: $e',
        );
      }
    }
    throw HealthObservationCipherException(
      'Unsupported ciphertext format: $format',
    );
  }

  Future<String> decryptEnvelope({
    required HealthObservationCipherEnvelope envelope,
    required Uint8List keyBytes,
  }) async {
    if (keyBytes.length != 32) {
      throw HealthObservationCipherException('AES-256 key must be 32 bytes');
    }
    try {
      final box = SecretBox(
        envelope.cipherText,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      );
      final clear = await _algorithm.decrypt(
        box,
        secretKey: SecretKey(keyBytes),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw HealthObservationCipherException(
        'Ciphertext authentication failed (tampered or wrong key)',
      );
    } catch (e) {
      if (e is HealthObservationCipherException) rethrow;
      throw HealthObservationCipherException(
        'Ciphertext decrypt failed: $e',
      );
    }
  }

  Future<String> decrypt({
    required String envelope,
    required Uint8List keyBytes,
  }) async {
    final parsed = parse(envelope);
    return decryptEnvelope(envelope: parsed, keyBytes: keyBytes);
  }

  static bool looksLikeEnvelope(String raw) {
    final t = raw.trim();
    return t.startsWith('$formatHob1.') || t.startsWith('$formatHob2.');
  }
}
