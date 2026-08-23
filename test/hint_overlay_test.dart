import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/controllers/game_controller.dart';
import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/models/hint_lesson.dart';
import 'package:sudoku_realms/services/hint_lesson_builder.dart';
import 'package:sudoku_realms/services/solver_step_parser.dart';
import 'package:sudoku_realms/utils/realm_theme.dart';
import 'package:sudoku_realms/widgets/hint_lesson_panel.dart';
import 'package:sudoku_realms/widgets/hint_overlay_painter.dart';
import 'package:sudoku_realms/widgets/sudoku_grid.dart';

/// A lesson built from real solver output, chosen for one that draws links so
/// the overlay has something to animate.
HintLesson _lessonWithLinks() {
  final steps = SolverStepParser.parseSolvePath(
    File('test/fixtures/solve_path.json').readAsStringSync(),
  );

  for (final step in steps) {
    final lesson = HintLessonBuilder.build(step);
    if (lesson.stages.any((s) => s.links.isNotEmpty) &&
        lesson.stages.length >= 3) {
      return lesson;
    }
  }
  return HintLessonBuilder.build(steps.first);
}

GameController _controller() {
  final id = Puzzles.allPuzzles.keys.firstWhere((k) => k.startsWith('classic'));
  return GameController(
    puzzleId: id,
    difficulty: Puzzles.getPuzzle(id)!.difficulty,
  );
}

Widget _gridHarness(GameController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 800,
        child: SingleChildScrollView(
          child: SudokuGrid(
            controller: controller,
            theme: RealmTheme.fromRealmSync('Classic Kingdom'),
          ),
        ),
      ),
    ),
  );
}

HintOverlayPainter? _painterOf(WidgetTester tester) {
  final matches = find
      .byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is HintOverlayPainter,
      )
      .evaluate();

  if (matches.isEmpty) return null;
  return (matches.first.widget as CustomPaint).painter as HintOverlayPainter;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('overlay', () {
    testWidgets('no overlay is drawn when no hint is active', (tester) async {
      final controller = _controller();

      await tester.pumpWidget(_gridHarness(controller));
      await tester.pump();

      expect(_painterOf(tester), isNull);
    });

    testWidgets('an active lesson paints the overlay', (tester) async {
      final controller = _controller();

      await tester.pumpWidget(_gridHarness(controller));
      await tester.pump();

      controller.gameState.activeLesson = _lessonWithLinks();
      controller.gameState.lessonStage = 0;
      controller.notifyListeners();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final painter = _painterOf(tester);
      expect(painter, isNotNull);
      expect(painter!.stage, controller.gameState.activeStage);

      // Let the entrance animation finish so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
      controller.gameState.activeLesson = null;
      controller.notifyListeners();
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets('the entrance animation runs, then completes', (tester) async {
      final controller = _controller();

      await tester.pumpWidget(_gridHarness(controller));
      await tester.pump();

      controller.gameState.activeLesson = _lessonWithLinks();
      controller.notifyListeners();
      await tester.pump();

      // Part way through, links should be partially drawn.
      await tester.pump(const Duration(milliseconds: 200));
      final midway = _painterOf(tester)!.progress;
      expect(midway, greaterThan(0.0));
      expect(midway, lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 800));
      expect(_painterOf(tester)!.progress, 1.0);

      controller.gameState.activeLesson = null;
      controller.notifyListeners();
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets('advancing a stage restarts the animation', (tester) async {
      final controller = _controller();

      await tester.pumpWidget(_gridHarness(controller));
      await tester.pump();

      controller.gameState.activeLesson = _lessonWithLinks();
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(_painterOf(tester)!.progress, 1.0);

      controller.nextLessonStage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // A fresh stage must animate in rather than appear fully formed.
      expect(_painterOf(tester)!.progress, lessThan(1.0));

      await tester.pump(const Duration(seconds: 1));
      controller.gameState.activeLesson = null;
      controller.notifyListeners();
      await tester.pump();
      await tester.pumpAndSettle();
    });

    testWidgets('marks and links stay inside the board', (tester) async {
      final lesson = _lessonWithLinks();

      for (final stage in lesson.stages) {
        for (final mark in stage.marks) {
          expect(mark.cell.row, inInclusiveRange(0, 8));
          expect(mark.cell.col, inInclusiveRange(0, 8));
        }
        for (final link in stage.links) {
          expect(link.from.row, inInclusiveRange(0, 8));
          expect(link.from.col, inInclusiveRange(0, 8));
          expect(link.to.row, inInclusiveRange(0, 8));
          expect(link.to.col, inInclusiveRange(0, 8));
        }
        for (final house in stage.houses) {
          expect(house.number, inInclusiveRange(1, 9));
        }
      }
    });
  });

  group('lesson panel', () {
    Widget panelHarness(
      HintLesson lesson,
      int stage, {
      VoidCallback? onNext,
      VoidCallback? onApply,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: HintLessonPanel(
            lesson: lesson,
            stageIndex: stage,
            onNext: onNext ?? () {},
            onBack: () {},
            onApply: onApply ?? () {},
            onClose: () {},
          ),
        ),
      );
    }

    testWidgets('shows the current stage text and position', (tester) async {
      final lesson = _lessonWithLinks();

      await tester.pumpWidget(panelHarness(lesson, 0));
      await tester.pump();

      // The narration is a RichText now, so its board references can be
      // colour-matched to the grid; find.text needs telling to look inside it.
      expect(
        find.text(lesson.stages.first.text, findRichText: true),
        findsOneWidget,
      );
      expect(find.text('1 / ${lesson.stages.length}'), findsOneWidget);
      expect(find.text(lesson.technique), findsOneWidget);
    });

    testWidgets('offers Next until the last stage, then Apply',
        (tester) async {
      final lesson = _lessonWithLinks();

      await tester.pumpWidget(panelHarness(lesson, 0));
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);

      await tester.pumpWidget(
        panelHarness(lesson, lesson.stages.length - 1),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsNothing);
      final applyLabel = lesson.isPlacement
          ? 'Place ${lesson.placementValue}'
          : 'Apply';
      expect(find.text(applyLabel), findsOneWidget);
    });

    testWidgets('the takeaway appears only at the end', (tester) async {
      final lesson = _lessonWithLinks();
      if (lesson.takeaway == null) return;

      await tester.pumpWidget(panelHarness(lesson, 0));
      await tester.pump();
      expect(find.text(lesson.takeaway!), findsNothing);

      await tester.pumpWidget(panelHarness(lesson, lesson.stages.length - 1));
      await tester.pumpAndSettle();
      expect(find.text(lesson.takeaway!), findsOneWidget);
    });

    testWidgets('Back is hidden on the first stage', (tester) async {
      final lesson = _lessonWithLinks();

      await tester.pumpWidget(panelHarness(lesson, 0));
      await tester.pump();
      expect(find.text('Back'), findsNothing);

      await tester.pumpWidget(panelHarness(lesson, 1));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Next fires the callback', (tester) async {
      final lesson = _lessonWithLinks();
      var advanced = 0;

      await tester.pumpWidget(panelHarness(lesson, 0, onNext: () => advanced++));
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(advanced, 1);
    });
  });

  group('controller lesson navigation', () {
    test('stages advance and clamp at both ends', () {
      final controller = _controller();
      final lesson = _lessonWithLinks();
      controller.gameState.activeLesson = lesson;

      expect(controller.gameState.lessonStage, 0);

      controller.previousLessonStage();
      expect(controller.gameState.lessonStage, 0, reason: 'clamps at the start');

      for (var i = 0; i < lesson.stages.length + 3; i++) {
        controller.nextLessonStage();
      }
      expect(controller.gameState.lessonStage, lesson.stages.length - 1,
          reason: 'clamps at the end');

      controller.previousLessonStage();
      expect(controller.gameState.lessonStage, lesson.stages.length - 2);
    });

    test('dismissing clears the lesson', () {
      final controller = _controller();
      controller.gameState.activeLesson = _lessonWithLinks();

      controller.dismissLesson();

      expect(controller.gameState.activeLesson, isNull);
      expect(controller.gameState.activeStage, isNull);
    });
  });
}
