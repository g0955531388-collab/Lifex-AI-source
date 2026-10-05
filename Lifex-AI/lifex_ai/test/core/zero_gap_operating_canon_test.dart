import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/architecture_registry/zero_gap_operating_canon.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  const canon = LifexZeroGapOperatingCanon();

  test('هوية النظام والحزمة ثابتة', () {
    expect(canon.systemName, 'Lifex-AI');
    expect(canon.packageName, 'lifex_ai');
    expect(canon.dartFlutterOnly, isTrue);
  });

  test('EMPTY بلا إجراء تالٍ مرفوض — EMPTY مع إجراء مقبول', () {
    expect(
      canon.emptyStateIsValid(
        hasExplanation: true,
        hasNextAction: false,
        claimsBlockedBySubscription: false,
      ),
      isFalse,
    );
    expect(
      canon.emptyStateIsValid(
        hasExplanation: true,
        hasNextAction: true,
        claimsBlockedBySubscription: false,
      ),
      isTrue,
    );
    expect(
      canon.emptyStateIsValid(
        hasExplanation: true,
        hasNextAction: true,
        claimsBlockedBySubscription: true,
      ),
      isFalse,
    );
  });

  test('متابعة وحدها زر ميت — التالي/تأكيد مقبولان', () {
    expect(canon.continueLabelIsAcceptable('متابعة'), isFalse);
    expect(canon.continueLabelIsAcceptable('متابعة الشحن'), isFalse);
    expect(canon.continueLabelIsAcceptable('التالي — وسيلة الدفع'), isTrue);
    expect(canon.continueLabelIsAcceptable('تأكيد الشحن'), isTrue);
  });

  test('رسالة Sandbox يجب أن تكون صريحة', () {
    expect(canon.sandboxMessageHonest('COMPLETED [SANDBOX] ok'), isTrue);
    expect(canon.sandboxMessageHonest('تم بنجاح'), isFalse);
  });

  test('مسار الشحن العالمي مكتمل الخطوات', () {
    expect(canon.topUpHappyPath.first, 'OPEN_WALLET');
    expect(canon.topUpHappyPath.last, 'SPOKEN_CONFIRMATION');
    expect(canon.topUpHappyPath.length, greaterThanOrEqualTo(10));
  });

  test('السيناريوهات الصوتية المعتمدة تُحلّ في المحلّل', () {
    final p = CommandParser();
    for (final phrase in canon.canonicalVoiceScenariosAr) {
      final intent = p.parse(phrase).intent;
      expect(
        intent != VoiceCommandIntent.unknown,
        isTrue,
        reason: 'فشل السيناريو: "$phrase" → $intent',
      );
    }
  });

  test('التقرير التشغيلي يصدّر المقاييس', () {
    final r = canon.asReport();
    expect(r['noFakeMoney'], isTrue);
    expect(r['noDeadContinue'], isTrue);
    expect((r['mustHaveScreens'] as int) >= 7, isTrue);
  });
}
