import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/core/license_manager.dart';

void main() {
  test('رابط التحقق وكلمة valid لا يفعّلان الترخيص', () {
    final manager = LicenseManager.instance;
    manager.clearLicense();
    final accepted = manager.acceptRemoteActivation(
      key: 'any-key',
      verifyUrl: 'https://example.invalid/verify?device=android-id',
      body: 'valid',
    );
    expect(accepted, isFalse);
    expect(LicenseManager.remoteBodyActivationAllowed, isFalse);
    expect(LicenseManager.postTrialDiscountIsLicense, isFalse);
    expect(manager.currentLicense, isNull);
    expect(manager.isAppUsageAllowed, isFalse);
    expect(AppConstants.trialPeriodDays, 30);
  });
}
