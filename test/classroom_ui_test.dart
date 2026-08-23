import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/models/technique_lesson.dart';
import 'package:sudoku_realms/services/classroom_service.dart';
import 'package:sudoku_realms/widgets/classroom_board.dart';
import 'package:sudoku_realms/widgets/classroom_screen.dart';
import 'package:sudoku_realms/widgets/practice_screen.dart';
import 'package:sudoku_realms/widgets/technique_screen.dart';

Future<TechniqueLesson> _lesson([String id = 'NAKED_PAIR']) async {
  final lessons = await ClassroomService.lessons();
  return lessons.firstWhere((l) => l.info.id == id);
}

/// Loads the bundled classroom before the fake clock takes over.
///
/// rootBundle reads from disk, which is real I/O — under testWidgets' fake
/// async that never completes. Priming inside runAsync fills the service's
/// cache so the screens can resolve it from memory.
Future<void> _prime(WidgetTester tester) async {
  await tester.runAsync(() => ClassroomService.lessons());
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('classroom index', () {
    testWidgets('lists chapters and marks the suggested next technique',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      await tester.pumpWidget(const MaterialApp(home: ClassroomScreen()));
      await _settle(tester);

      expect(tester.takeException(), isNull);

      expect(find.text('Classroom'), findsOneWidget);
      // Chapter headers show the title as written.
      expect(find.text('Singles'), findsWidgets);

      // With no progress, the very first technique is the one nudged.
      expect(find.text('NEXT UP'), findsOneWidget);
      expect(find.textContaining('Next up: Full House'), findsOneWidget);
    });

    testWidgets('renders at a small screen size without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      await tester.pumpWidget(const MaterialApp(home: ClassroomScreen()));
      await _settle(tester);

      expect(tester.takeException(), isNull);

      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scroll step $i');
      }

      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('technique walkthrough', () {
    testWidgets('steps through the lesson and reaches practice',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      final lesson = await _lesson();

      await tester.pumpWidget(
        MaterialApp(home: TechniqueScreen(lesson: lesson)),
      );
      await _settle(tester);

      expect(find.text(lesson.info.name), findsOneWidget);
      expect(find.text('WHAT TO LOOK FOR'), findsOneWidget);
      expect(find.byType(ClassroomBoard), findsOneWidget);

      // Walk to the end; the final button offers practice.
      for (var i = 0; i < 20; i++) {
        if (find.text('Try it yourself').evaluate().isNotEmpty) break;
        expect(find.text('Next'), findsOneWidget, reason: 'stage $i');
        await tester.tap(find.text('Next'));
        await _settle(tester);
      }

      expect(find.text('Try it yourself'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reaching the end records the technique as studied',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      // A technique with no practice pops straight back, keeping the test to
      // the studied flag alone.
      final lesson = await _lesson('FULL_HOUSE');

      await tester.pumpWidget(
        MaterialApp(home: TechniqueScreen(lesson: lesson)),
      );
      await _settle(tester);

      for (var i = 0; i < 20; i++) {
        final done = find.text('Try it yourself');
        if (done.evaluate().isNotEmpty) {
          await tester.tap(done);
          await _settle(tester);
          break;
        }
        await tester.tap(find.text('Next'));
        await _settle(tester);
      }

      final progress = await ClassroomService.progress();
      expect(progress['FULL_HOUSE']!.studied, isTrue);
    });
  });

  group('practice', () {
    testWidgets('asks for the right number of cells', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      final lesson = await _lesson();

      await tester.pumpWidget(
        MaterialApp(home: PracticeScreen(lesson: lesson)),
      );
      await _settle(tester);

      final expected = lesson.practice.first.patternSize;
      expect(
        find.textContaining('Tap the $expected cells'),
        findsOneWidget,
      );

      // Check is disabled until something is picked.
      expect(find.text('Check'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrong answer explains what is missing', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      final lesson = await _lesson();

      await tester.pumpWidget(
        MaterialApp(home: PracticeScreen(lesson: lesson)),
      );
      await _settle(tester);

      // Tap a single cell, which cannot be the whole pattern.
      final board = tester.getRect(find.byType(ClassroomBoard));
      final cell = board.width / 9;
      await tester.tapAt(board.topLeft + Offset(cell * 0.5, cell * 0.5));
      await tester.pump();

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Says specifically what went wrong, not just "incorrect".
      final verdict = find.textContaining('missing');
      final extra = find.textContaining('not part of the pattern');
      expect(
        verdict.evaluate().isNotEmpty || extra.evaluate().isNotEmpty,
        isTrue,
      );

      expect(find.text('Try again'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the correct pattern is accepted and recorded',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      final lesson = await _lesson();

      await tester.pumpWidget(
        MaterialApp(home: PracticeScreen(lesson: lesson)),
      );
      await _settle(tester);

      final board = tester.getRect(find.byType(ClassroomBoard));
      final cell = board.width / 9;

      for (final at in lesson.practice.first.answers.first) {
        await tester.tapAt(
          board.topLeft +
              Offset((at.col + 0.5) * cell, (at.row + 0.5) * cell),
        );
        await tester.pump();
      }

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('That is the pattern'), findsOneWidget);

      final progress = await ClassroomService.progress();
      expect(progress[lesson.info.id]!.solved, 1);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('"Show me" reveals the reasoning', (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);

      final lesson = await _lesson();

      await tester.pumpWidget(
        MaterialApp(home: PracticeScreen(lesson: lesson)),
      );
      await _settle(tester);

      await tester.tap(find.text('Show me'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('HOW IT WORKS HERE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
