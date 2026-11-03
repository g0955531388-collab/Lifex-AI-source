/// =============================================================
/// Lifex-AI — الطوارئ المتعددة الحواس — اختبارات
/// الملف: platform_vibration_executor_test.dart
/// الوصف: اختبارات الاهتزاز.
/// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vibration/vibration.dart';

import 'package:lifex_ai/features/energy/platform_vibration_executor.dart';

class MockVibration extends Mock implements Vibration {}

void main() {
  group('PlatformVibrationExecutor', () {
    late MockVibration mockVibration;
    late PlatformVibrationExecutor executor;

    setUp(() {
      mockVibration = MockVibration();
      executor = PlatformVibrationExecutor(vibration: mockVibration);
    });

    test('vibrate succeeds when vibrator available', () async {
      when(mockVibration.hasVibrator())
          .thenAnswer((_) async => true);
      when(mockVibration.vibrate(
        amplitude: any(named: 'amplitude'),
        duration: any(named: 'duration'),
      )).thenAnswer((_) async {});

      await executor.vibrate(patternMs: [300]);
      
      verify(mockVibration.hasVibrator()).called(1);
    });

    test('vibrate handles no vibrator gracefully', () async {
      when(mockVibration.hasVibrator())
          .thenAnswer((_) async => false);

      await executor.vibrate(patternMs: [300]);
      
      verifyNever(mockVibration.vibrate(
        amplitude: any(named: 'amplitude'),
        duration: any(named: 'duration'),
      ));
    });

    test('vibrate handles exception gracefully', () async {
      when(mockVibration.hasVibrator())
          .thenThrow(Exception('Test error'));

      await executor.vibrate(patternMs: [300]);
      
      // Should not throw
      expect(executor, isNotNull);
    });

    test('vibrate uses amplitude when available', () async {
      when(mockVibration.hasVibrator())
          .thenAnswer((_) async => true);
      when(mockVibration.hasAmplitudeControl())
          .thenAnswer((_) async => true);
      when(mockVibration.vibrate(
        amplitude: any(named: 'amplitude'),
        duration: any(named: 'duration'),
      )).thenAnswer((_) async {});

      await executor.vibrate(patternMs: [300]);
      
      verify(mockVibration.hasAmplitudeControl()).called(1);
    });
  });
}
