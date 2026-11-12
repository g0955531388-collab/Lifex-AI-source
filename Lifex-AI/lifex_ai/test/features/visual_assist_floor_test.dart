import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/visual_assist_floor.dart';

void main() {
  tearDown(VisualAssistFloorSwitch.debugReset);

  test('taking the floor tells the listener that is still registered', () {
    final seen = <VisualAssistFloor>[];
    void hear(VisualAssistFloor floor) => seen.add(floor);
    VisualAssistFloorSwitch.listen(hear);
    VisualAssistFloorSwitch.take(VisualAssistFloor.legacy);
    VisualAssistFloorSwitch.unlisten(hear);
    VisualAssistFloorSwitch.take(VisualAssistFloor.spot);
    expect(seen, [VisualAssistFloor.legacy]);
    expect(VisualAssistFloorSwitch.active, VisualAssistFloor.spot);
  });

  testWidgets('opening SPOT removes the old assistant immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _FloorPage(
                    floor: VisualAssistFloor.legacy,
                    title: 'legacy',
                  ),
                ),
              );
            },
            child: const Text('open-legacy'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-legacy'));
    await tester.pumpAndSettle();
    expect(find.text('legacy'), findsOneWidget);

    await tester.tap(find.text('open-other'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('spot'), findsOneWidget);
    expect(find.text('legacy'), findsNothing);
  });

  testWidgets('opening the old assistant removes SPOT immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _FloorPage(floor: VisualAssistFloor.spot, title: 'spot'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('spot'), findsOneWidget);

    await tester.tap(find.text('open-other'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('legacy'), findsOneWidget);
    expect(find.text('spot'), findsNothing);
  });
}

class _FloorPage extends StatefulWidget {
  const _FloorPage({required this.floor, required this.title});

  final VisualAssistFloor floor;
  final String title;

  @override
  State<_FloorPage> createState() => _FloorPageState();
}

class _FloorPageState extends State<_FloorPage> {
  var _left = false;

  @override
  void initState() {
    super.initState();
    VisualAssistFloorSwitch.listen(_onFloor);
    VisualAssistFloorSwitch.take(widget.floor);
  }

  void _onFloor(VisualAssistFloor floor) {
    if (floor == widget.floor || _left) return;
    _left = true;
    handOffVisualAssist(context, mounted: () => mounted);
  }

  @override
  void dispose() {
    VisualAssistFloorSwitch.unlisten(_onFloor);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.floor == VisualAssistFloor.legacy
        ? VisualAssistFloor.spot
        : VisualAssistFloor.legacy;
    final otherTitle = other == VisualAssistFloor.spot ? 'spot' : 'legacy';
    return Scaffold(
      body: Column(
        children: [
          Text(widget.title),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FloorPage(floor: other, title: otherTitle),
                ),
              );
            },
            child: const Text('open-other'),
          ),
        ],
      ),
    );
  }
}
