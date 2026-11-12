import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_walk_speech.dart';

void main() {
  test('أسماء الإطار تُقدَّم بلا مسافة والجملة الجاهزة تبقى', () {
    expect(BlindWalkSpeech.line('شخص، سيارة', arabic: true), 'في الإطار: شخص، سيارة.');
    expect(BlindWalkSpeech.line('car', arabic: false), 'In the frame: car.');
    expect(
      BlindWalkSpeech.line('لن أخترع مشهداً.', arabic: true),
      'لن أخترع مشهداً.',
    );
    expect(
      BlindWalkSpeech.line('في الإطار: شخص، سيارة.', arabic: true).contains('متر'),
      isFalse,
    );
  });

  test('النطق لا يُقطع إلا إذا تغيّر العائق', () {
    expect(BlindWalkSpeech.hardHazard('في الإطار: سيارة.'), isTrue);
    expect(BlindWalkSpeech.hardHazard('في الإطار: سماء.'), isFalse);
    expect(
      BlindWalkSpeech.yieldToCurrentSpeech(
        speaking: true,
        hazardKey: '',
        heardHazardKey: '',
      ),
      isTrue,
    );
    expect(
      BlindWalkSpeech.yieldToCurrentSpeech(
        speaking: true,
        hazardKey: 'سيارة',
        heardHazardKey: '',
      ),
      isFalse,
    );
    expect(
      BlindWalkSpeech.yieldToCurrentSpeech(
        speaking: true,
        hazardKey: 'درج',
        heardHazardKey: 'سيارة',
      ),
      isFalse,
    );
    expect(
      BlindWalkSpeech.yieldToCurrentSpeech(
        speaking: false,
        hazardKey: 'سيارة',
        heardHazardKey: '',
      ),
      isFalse,
    );
  });
}
