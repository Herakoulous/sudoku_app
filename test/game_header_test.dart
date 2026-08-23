import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/utils/realm_theme.dart';
import 'package:sudoku_realms/widgets/game_header.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// The header sits on the game screen at full device width. It packs an exit
  /// button, the title, a difficulty meter, three action buttons and a timer
  /// into one row — the difficulty meter carrying a tier name like "Apprentice"
  /// is what pushed it over on a narrow phone.
  Future<void> pumpAt(WidgetTester tester, Size size, int difficulty) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameHeader(
            difficulty: difficulty,
            puzzleId: 'classic 14',
            elapsedTime: const Duration(seconds: 2),
            onRestart: () {},
            onExit: () {},
            theme: RealmTheme.fromRealmSync('Classic Kingdom'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('does not overflow on a narrow phone at any difficulty',
      (tester) async {
    // The reported overflow was at Apprentice (the longest early tier name), on
    // a ~360-wide screen. Check every difficulty, since each maps to a tier
    // name of a different length.
    for (var difficulty = 1; difficulty <= 10; difficulty++) {
      await pumpAt(tester, const Size(360, 780), difficulty);
      expect(tester.takeException(), isNull,
          reason: 'difficulty $difficulty overflowed');
    }
  });

  testWidgets('holds up on a very small screen', (tester) async {
    await pumpAt(tester, const Size(320, 568), 3);
    expect(tester.takeException(), isNull);
  });
}
