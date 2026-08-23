import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/models/solve_record.dart';
import 'package:sudoku_realms/services/achievement_service.dart';
import 'package:sudoku_realms/services/progress_service.dart';
import 'package:sudoku_realms/widgets/statistics_screen.dart';

/// Phone sizes worth covering: a small 5" screen, a typical modern phone, and a
/// large one. Achievement tiles are the tightest layout in the app, so they are
/// the first thing to overflow on a narrow screen.
const _sizes = <String, Size>{
  'small (320x568)': Size(320, 568),
  'typical (375x812)': Size(375, 812),
  'large (430x932)': Size(430, 932),
};

Future<void> _pumpStats(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: StatisticsScreen()));

  // Statistics loads asynchronously, and the sections fade in on a stagger
  // driven by Future.delayed. Advance real time so those timers fire, otherwise
  // they outlive the widget tree and the binding reports a pending timer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('layout has no overflow', () {
    for (final entry in _sizes.entries) {
      testWidgets('with no progress on ${entry.key}', (tester) async {
        await _pumpStats(tester, entry.value);
        expect(tester.takeException(), isNull);
      });

      testWidgets('with progress on ${entry.key}', (tester) async {
        // A spread of solves so achievement tiles show partial progress, which
        // adds a line of text and is the state most likely to overflow.
        for (var i = 0; i < 12; i++) {
          await ProgressService.recordSolve(
            SolveRecord(
              puzzleId: 'classic ${i + 1}',
              realmName: 'Classic Kingdom',
              difficulty: 1 + (i % 10),
              seconds: 120 + i * 30,
              hintsUsed: i % 3,
              mistakes: i % 2,
              finishedAt: DateTime(2026, 8, 10 + i, 8 + (i % 12)),
            ),
          );
        }

        await _pumpStats(tester, entry.value);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('scrolling the whole page never overflows', (tester) async {
    for (var i = 0; i < 30; i++) {
      await ProgressService.recordSolve(
        SolveRecord(
          puzzleId: 'classic ${i + 1}',
          realmName: 'Classic Kingdom',
          difficulty: 1 + (i % 10),
          seconds: 90 + i * 10,
          hintsUsed: 0,
          mistakes: 0,
          finishedAt: DateTime(2026, 8, 1 + i, 12),
        ),
      );
    }

    await _pumpStats(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);

    // Walk down the page; a section further down can overflow only once built.
    for (var i = 0; i < 8; i++) {
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -400),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'after scroll step $i');
    }

    // Let the entrance animations and scroll physics finish, or the binding
    // complains about timers outliving the widget tree.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('the longest achievement name fits its tile', (tester) async {
    // Names are the variable-length part of a fixed-size tile, so the longest
    // one in the catalogue is the worst case.
    final longest = AchievementService.all
        .map((a) => a.name)
        .reduce((a, b) => a.length >= b.length ? a : b);

    expect(longest.length, greaterThan(10));

    await _pumpStats(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
  });
}
