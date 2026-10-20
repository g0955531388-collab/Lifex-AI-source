import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/admin/owner_identity_policy.dart';
import 'package:lifex_ai/core/app_constants.dart';

void main() {
  const policy = OwnerIdentityPolicy();

  test('الرقم الدولي المخزّن يطابق هاتف المالك', () {
    expect(
      policy.matchesOwnerPhone(AppConstants.ownerPhoneNumber),
      isTrue,
    );
    expect(policy.matchesOwnerPhone('+963 955-531388'), isTrue);
  });

  test('الصيغ المحلية اللاتينية تبقى مطابقة', () {
    expect(policy.matchesOwnerPhone('0955531388'), isTrue);
    expect(policy.matchesOwnerPhone('955531388'), isTrue);
  });

  test('الرقم المحلي بالأرقام العربية الهندية يطابق المالك', () {
    expect(policy.matchesOwnerPhone('٠٩٥٥٥٣١٣٨٨'), isTrue);
    expect(policy.matchesOwnerPhone('٠٩٥٥-٥٣١٣٨٨'), isTrue);
    expect(policy.matchesOwnerPhone('٩٥٥٥٣١٣٨٨'), isTrue);
    expect(policy.matchesOwnerPhone('+٩٦٣٩٥٥٥٣١٣٨٨'), isTrue);
  });

  test('رقم مختلف لا يحصل على مطابقة المالك', () {
    expect(policy.matchesOwnerPhone('٠٩٥٥٥٣١٣٨٩'), isFalse);
    expect(policy.matchesOwnerPhone('+963955531389'), isFalse);
    expect(policy.matchesOwnerPhone('+10000000000'), isFalse);
    expect(policy.matchesOwnerPhone(null), isFalse);
    expect(policy.matchesOwnerPhone('   '), isFalse);
  });

  test('النص الأطول الذي ينتهي بأرقام المالك لا يطابق', () {
    expect(policy.matchesOwnerPhone('963955531388'), isFalse);
    expect(policy.matchesOwnerPhone('00963955531388'), isFalse);
    expect(policy.matchesOwnerPhone('+19999555531388'), isFalse);
    expect(policy.matchesOwnerPhone('123955531388'), isFalse);
    expect(policy.matchesOwnerPhone('٩٦٣٩٥٥٥٣١٣٨٨'), isFalse);
    expect(policy.matchesOwnerPhone('٠٠٩٦٣٩٥٥٥٣١٣٨٨'), isFalse);
  });
}
