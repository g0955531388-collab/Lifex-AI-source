import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/screens/live_sight_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('خروج التطبيق إلى الخلفية يغلق المساعد البصري ولا يبقي عدسة حية',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
    messenger.setMockMethodCallHandler(permissions, (call) async {
      if (call.method == 'checkPermissionStatus') return 0;
      if (call.method == 'requestPermissions') {
        final asked = (call.arguments as List).cast<int>();
        return {for (final p in asked) p: 0};
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));

    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('home')),
    ));
    nav.currentState!.push(
      MaterialPageRoute(builder: (_) => const LiveSightScreen(profileId: '')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LiveSightScreen), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LiveSightScreen), findsOneWidget,
        reason: 'نافذة الإذن لا تغلق الشاشة');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 400));

    // الإطارات متوقفة في الخلفية؛ الشاشة المغلقة تظهر عند العودة.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(LiveSightScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
