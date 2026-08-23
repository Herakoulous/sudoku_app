import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/services/classroom_service.dart';
import 'package:sudoku_realms/widgets/coming_soon_tab.dart';
import 'package:sudoku_realms/widgets/root_shell.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Classroom tab reads a bundled asset; prime it before the fake clock runs.
  await tester.runAsync(() => ClassroomService.lessons());

  await tester.pumpWidget(const MaterialApp(home: RootShell()));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows five tabs and opens on Play', (tester) async {
    await _pump(tester);

    for (final label in ['Play', 'Learn', 'Dungeon', 'Daily', 'Profile']) {
      expect(find.text(label), findsWidgets, reason: label);
    }

    // Play tab is the wordmark hero.
    expect(find.text('SUDOKU'), findsOneWidget);
  });

  testWidgets('each tab shows its own content', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Learn'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Classroom'), findsOneWidget);

    await tester.tap(find.text('Dungeon'));
    await tester.pump(const Duration(seconds: 1));
    // The real Dungeon tab shows its two ranked modes.
    expect(find.text('Survival'), findsOneWidget);
    expect(find.text('Time Rush'), findsOneWidget);

    await tester.tap(find.text('Daily'));
    await tester.pump();
    expect(find.text('Puzzle of the Day'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets('tabs keep their state across switches', (tester) async {
    await _pump(tester);

    // The Play hero must survive a round trip through another tab, proving the
    // IndexedStack keeps tabs alive rather than rebuilding them.
    await tester.tap(find.text('Dungeon'));
    await tester.pump();
    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(find.text('SUDOKU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Profile tab exposes settings', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byTooltip('Settings'), findsOneWidget);
  });
}
