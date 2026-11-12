import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/access_mode_preference.dart';

void main() {
  test('ملف المكفوف يفعّل الوضع وقرار المستخدم يبقى', () {
    final fromProfile = AccessModePreference.decide(
      profileNeedsAccess: true,
      storedEnabled: null,
      userChose: false,
    );
    expect(fromProfile.enabled, isTrue);
    expect(fromProfile.userChose, isFalse);

    final keptOff = AccessModePreference.decide(
      profileNeedsAccess: true,
      storedEnabled: false,
      userChose: true,
    );
    expect(keptOff.enabled, isFalse);

    final anyone = AccessModePreference.decide(
      profileNeedsAccess: false,
      storedEnabled: true,
      userChose: true,
    );
    expect(anyone.enabled, isTrue);
    expect(AccessModePreference.requestsPlatformPermissions, isFalse);
    expect(AccessModePreference.enablesTalkBackSilently, isFalse);
    expect(AccessModePreference.profileNeedsAccess(isBlind: false), isFalse);
  });

  testWidgets('مفتاح وضع الوصول له اسم دلالي وهدف لمس واسع', (tester) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwitchListTile(
            title: Text(AccessModePreference.title(english: false)),
            subtitle: Text(AccessModePreference.subtitle(english: false)),
            value: enabled,
            onChanged: (value) => enabled = value,
          ),
        ),
      ),
    );
    expect(find.text('وضع الوصول'), findsOneWidget);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('وضع الوصول')).label,
      contains('وضع الوصول'),
    );
    expect(tester.getSize(find.byType(SwitchListTile)).height, greaterThan(48));
    await tester.tap(find.byType(SwitchListTile));
    expect(enabled, isTrue);
    handle.dispose();
  });
}
