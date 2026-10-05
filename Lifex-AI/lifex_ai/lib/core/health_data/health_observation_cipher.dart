/// =============================================================
/// Lifex-AI — AES-256-GCM لـ HealthObservation at-rest
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

/// تشفير/فك AES-256-GCM.
class AesGcmHealthObservationCipher {
  AesGcmHealthObservationCipher({AesGcm? algorithm})
      : _algorithm = algorithm ?? AesGcm.with256bits();

  static const algorithmId = 'AES-256-GCM';
  static const envelopeVersion = 'LIFEXHOB1';

  final AesGcm _algorithm;

  Future<String> encrypt({
    required String plaintext,
    required Uint8List keyBytes,
  }) async {
    if (keyBytes.length != 32) {
      throw HealthObservationCipherException('AES-256 key must be 32 bytes');
    }
    final secretKey = SecretKey(keyBytes);
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );
    final nonce = base64Url.encode(box.nonce);
    final cipherText = base64Url.encode(box.cipherText);
    final mac = base64Url.encode(box.mac.bytes);
    return '$envelopeVersion.$nonce.$cipherText.$mac';
  }

  Future<String> decrypt({
    required String envelope,
    required Uint8List keyBytes,
  }) async {
    if (keyBytes.length != 32) {
      throw HealthObservationCipherException('AES-256 key must be 32 bytes');
    }
    final parts = envelope.trim().split('.');
    if (parts.length != 4 || parts[0] != envelopeVersion) {
      throw HealthObservationCipherException(
        'Unrecognized or tampered ciphertext envelope',
      );
    }
    try {
      final nonce = base64Url.decode(parts[1]);
      final cipherText = base64Url.decode(parts[2]);
      final macBytes = base64Url.decode(parts[3]);
      final box = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
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

  /// كشف سريع: هل المحتوى يبدو كمغلف مشفّر؟
  static bool looksLikeEnvelope(String raw) {
    final t = raw.trim();
    return t.startsWith('$envelopeVersion.');
  }
}
