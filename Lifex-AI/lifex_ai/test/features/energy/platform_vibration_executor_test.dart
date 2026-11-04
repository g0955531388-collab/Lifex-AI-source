import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/energy/platform_vibration_executor.dart';

void main() {
  test('platform vibration adapter safely handles unavailable test platform', () async {
    final executor = PlatformVibrationExecutor();
    await expectLater(
      executor.vibrate(patternMs: const [120, 80, 120]),
      completes,
    );
  });
}
