import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/features/outreach/encyclopedia_share_bridge.dart';
import 'package:lifex_ai/features/outreach/lifex_public_brief.dart';
import 'package:lifex_ai/features/outreach/partner_sign_in_policy.dart';

void main() {
  test('نبذة المشاركة تتضمن الخدمات والإسناد والأسعار', () {
    final text = const LifexPublicBrief().fullAr;
    expect(text.contains('موسوعة'), isTrue);
    expect(text.contains('100'), isTrue);
    expect(text.contains('300'), isTrue);
    expect(text.contains('600'), isTrue);
    expect(text.contains(AppConstants.ownershipStatement), isTrue);
    expect(text.contains('غازي سليم بكفلاوي'), isTrue);
    expect(text.contains('ملف صحي'), isTrue);
    expect(text.toLowerCase().contains('pornhub'), isFalse);
  });

  test('المواقع الإباحية محظورة وأي موقع آخر غير شريك لا يُفتح وهمياً', () {
    const policy = PartnerSignInPolicy();
    expect(
      policy.evaluate('https://www.pornhub.com').kind,
      PartnerSignInKind.adultBlocked,
    );
    expect(
      policy.evaluate('chatgpt.com').kind,
      PartnerSignInKind.notPartner,
    );
    expect(policy.evaluate('chatgpt.com').mayProceed, isFalse);
    expect(policy.evaluate('chatgpt.com').offersLocalAccount, isTrue);
    expect(policy.evaluate('https://www.pornhub.com').offersLocalAccount, isFalse);
    expect(
      policy.evaluate('https://gemini.google.com').kind,
      PartnerSignInKind.notPartner,
    );
  });

  test('الشريك المسجّل فقط يجوز إبراز المعرّف', () {
    const policy = PartnerSignInPolicy(partnerHosts: {'clinic.example'});
    final ok = policy.evaluate('https://clinic.example/login');
    expect(ok.kind, PartnerSignInKind.allowedPartner);
    expect(ok.mayProceed, isTrue);
  });

  test('المشاركة تنسخ النبذة إن لم توجد ورقة نظام', () async {
    var copied = '';
    final bridge = EncyclopediaShareBridge(
      copy: (text) async => copied = text,
    );
    final result = await bridge.shareEncyclopedia();
    expect(result.openedSheet, isFalse);
    expect(result.copied, isTrue);
    expect(copied.contains('100'), isTrue);
  });
}
