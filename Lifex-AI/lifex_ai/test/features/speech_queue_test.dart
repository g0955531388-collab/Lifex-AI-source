import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/capture_focus.dart';
import 'package:lifex_ai/features/accessibility/scan_mode.dart';
import 'package:lifex_ai/features/voice/speech_queue.dart';

void main() {
  test('الطلب العادي يُرفض أثناء نطق جارٍ', () async {
    final queue = SpeechQueue();
    final hold = Completer<void>();
    var calls = 0;
    final first = queue.speakQueued(
      text: 'كرسي',
      speak: (_) async {
        calls++;
        await hold.future;
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    final second = await queue.speakQueued(
      text: 'باب',
      speak: (_) async {
        calls++;
        return true;
      },
    );
    expect(second, isFalse);
    expect(calls, 1);
    hold.complete();
    expect(await first, isTrue);
  });

  test('عاجل جديد يلغي اهتزاز الجملة التي لم تنتهِ', () async {
    final queue = SpeechQueue();
    final hold = Completer<void>();
    var firstHaptic = 0;
    var secondHaptic = 0;
    final first = queue.speakInterruptible(
      text: 'كرسي',
      stop: () async {},
      hapticAfter: () async {
        firstHaptic++;
      },
      speak: (_) async {
        await hold.future;
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    final second = queue.speakInterruptible(
      text: 'درج',
      stop: () async {
        if (!hold.isCompleted) hold.complete();
      },
      hapticAfter: () async {
        secondHaptic++;
      },
      speak: (_) async => true,
    );
    expect(await second, isTrue);
    await first;
    expect(firstHaptic, 0);
    expect(secondHaptic, 1);
  });

  test('الاهتزاز ينتظر نهاية الجملة', () async {
    final queue = SpeechQueue();
    final hold = Completer<void>();
    var haptic = 0;
    final pending = queue.speakInterruptible(
      text: 'سيارة',
      stop: () async {},
      hapticAfter: () async {
        haptic++;
      },
      speak: (_) async {
        await hold.future;
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(haptic, 0);
    hold.complete();
    expect(await pending, isTrue);
    expect(haptic, 1);
  });

  test('التركيز لا يعلق الالتقاط بعد 800ms', () async {
    final hold = Completer<void>();
    final focused = await focusBeforeCapture(
      () => hold.future,
      budget: const Duration(milliseconds: 20),
    );
    expect(focused, isFalse);
  });

  test('وضع المسح ينطق الجديد فقط', () {
    expect(
      scanSpeechDelta(previous: const ['كرسي'], next: const ['كرسي', 'شخص']),
      ['شخص'],
    );
    expect(
      scanSpeechDelta(previous: const ['كرسي'], next: const ['كرسي']),
      isEmpty,
    );
  });
}
