import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/screens/splash_screen.dart';
import 'package:lifex_ai/widgets/accessible_widgets.dart';
import 'package:lifex_ai/widgets/studio_web_frame.dart';

void main() {
  test('blind copy names the profile gate and keeps the cane', () {
    expect(BlindNavigationCopy.needsProfile, contains('ملفي الصحي'));
    expect(BlindNavigationCopy.obstacleUnavailable, contains('العصا البيضاء'));
    expect(BlindNavigationCopy.obstacleUnavailable, contains('غير متاح'));
  });

  testWidgets('talkback splash stays until the enter button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(displayDuration: Duration(milliseconds: 50)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(lifexUi('دخول', 'Enter')), findsOneWidget);
  });

  testWidgets('studio shell survives a route replacement', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            StudioWebCanvas(child: child ?? const SizedBox.shrink()),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const Text('next'),
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('next'), findsOneWidget);
  });
}
