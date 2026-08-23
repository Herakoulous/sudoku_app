import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/controllers/game_controller.dart';
import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/models/hint_lesson.dart';
import 'package:sudoku_realms/models/solver_step.dart';
import 'package:sudoku_realms/models/sudoku_cell.dart';
import 'package:sudoku_realms/services/hint_lesson_builder.dart';
import 'package:sudoku_realms/services/solver_step_parser.dart';

List<SolverStep> _steps() => SolverStepParser.parseSolvePath(
      File('test/fixtures/solve_path.json').readAsStringSync(),
    );

HintLesson? _firstLesson(bool Function(HintLesson) test) {
  for (final step in _steps()) {
    final lesson = HintLessonBuilder.build(step);
    if (test(lesson)) return lesson;
  }
  return null;
}

/// A controller whose board matches the grid the lesson was computed against.
///
/// The fixture comes from a different puzzle than any bundled one, so a plain
/// controller would have givens exactly where the lesson expects empty cells and
/// every note would be skipped.
GameController _controllerFor(SolverStep step) {
  final id = Puzzles.allPuzzles.keys.firstWhere((k) => k.startsWith('classic'));
  final controller = GameController(
    puzzleId: id,
    difficulty: Puzzles.getPuzzle(id)!.difficulty,
  );

  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      final value = step.grid[r * 9 + c];
      controller.gameState.grid[r][c] = value == 0
          ? SudokuCell.empty(row: r, col: c)
          : SudokuCell.given(row: r, col: c, number: value);
    }
  }

  return controller;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('note style', () {
    test('placement lessons reveal nothing', () {
      final lesson = _firstLesson((l) => l.isPlacement);
      expect(lesson, isNotNull);
      expect(lesson!.notesToReveal(), isEmpty,
          reason: 'placing a digit needs no pencil marks written first');
    });

    test('digit-centric techniques use side notes', () {
      // Pointing tracks one digit across a box and a line.
      for (final step in _steps()) {
        if (step.type != 'LOCKED_CANDIDATES_1') continue;
        final lesson = HintLessonBuilder.build(step);
        expect(lesson.noteStyle, NoteStyle.side, reason: step.type);
        return;
      }
    });

    test('cell-centric techniques use centre notes', () {
      for (final step in _steps()) {
        if (step.type != 'XY_WING') continue;
        final lesson = HintLessonBuilder.build(step);
        expect(lesson.noteStyle, NoteStyle.centre, reason: step.type);
        return;
      }
    });

    test('side-note lessons reveal only the digits under discussion', () {
      final lesson = _firstLesson(
        (l) => !l.isPlacement && l.noteStyle == NoteStyle.side,
      );
      if (lesson == null) return;

      final notes = lesson.notesToReveal();
      expect(notes, isNotEmpty);

      final digits = lesson.focusDigits;
      for (final note in notes) {
        expect(digits, contains(note.value),
            reason: 'a side note outside the digits being discussed is noise');
      }
    });

    test('centre-note lessons reveal whole candidate sets', () {
      final lesson = _firstLesson(
        (l) => !l.isPlacement && l.noteStyle == NoteStyle.centre,
      );
      if (lesson == null) return;

      final notes = lesson.notesToReveal();
      expect(notes, isNotEmpty);

      // Every revealed note must be a genuine candidate of that cell.
      for (final note in notes) {
        expect(
          lesson.step.candidatesOf(note.cell),
          contains(note.value),
          reason: '${note.cell.label} does not hold ${note.value}',
        );
      }
    });

    test('never reveals a note in a solved cell', () {
      for (final step in _steps()) {
        final lesson = HintLessonBuilder.build(step);
        for (final note in lesson.notesToReveal()) {
          expect(step.valueAt(note.cell), 0,
              reason: '${note.cell.label} is already filled');
        }
      }
    });

    test('the eliminated candidates are among those revealed', () {
      // The whole point: what the hint strikes out must be visible first.
      for (final step in _steps()) {
        final lesson = HintLessonBuilder.build(step);
        if (lesson.isPlacement || step.eliminations.isEmpty) continue;

        final revealed = lesson.notesToReveal().toSet();

        for (final elimination in step.eliminations) {
          expect(
            revealed.contains(elimination),
            isTrue,
            reason: '${lesson.technique}: ${elimination.cell.label} loses '
                '${elimination.value}, but that note is never written',
          );
        }
      }
    });
  });

  group('applying an elimination lesson', () {
    test('writes the notes, then strikes the eliminated ones', () async {
      final lesson = _firstLesson(
        (l) => !l.isPlacement && l.step.eliminations.isNotEmpty,
      );
      expect(lesson, isNotNull);

      final controller = _controllerFor(lesson!.step);
      controller.gameState.activeLesson = lesson;
      await controller.applyLesson();

      final step = lesson.step;

      // Eliminated candidates must NOT be on the board.
      for (final elimination in step.eliminations) {
        final cell = controller.gameState.grid[elimination.cell.row]
            [elimination.cell.col];
        if (cell.number != null) continue;

        expect(cell.centerNotes, isNot(contains(elimination.value)),
            reason: '${elimination.cell.label} kept ${elimination.value}');
        expect(cell.sideNotes, isNot(contains(elimination.value)),
            reason: '${elimination.cell.label} kept ${elimination.value}');
      }

      // Something must have been written, or the board is still blank and the
      // hint achieved nothing visible.
      var written = 0;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final cell = controller.gameState.grid[r][c];
          written += cell.centerNotes.length + cell.sideNotes.length;
        }
      }
      expect(written, greaterThan(0));
    });

    test('notes land in the style the technique calls for', () async {
      for (final style in NoteStyle.values) {
        final lesson = _firstLesson(
          (l) =>
              !l.isPlacement &&
              l.noteStyle == style &&
              l.step.eliminations.isNotEmpty,
        );
        if (lesson == null) continue;

        final controller = _controllerFor(lesson!.step);
        controller.gameState.activeLesson = lesson;
        await controller.applyLesson();

        var centre = 0;
        var side = 0;
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            centre += controller.gameState.grid[r][c].centerNotes.length;
            side += controller.gameState.grid[r][c].sideNotes.length;
          }
        }

        if (style == NoteStyle.centre) {
          expect(centre, greaterThan(0), reason: lesson.technique);
          expect(side, 0, reason: '${lesson.technique} wrote side notes');
        } else {
          expect(side, greaterThan(0), reason: lesson.technique);
          expect(centre, 0, reason: '${lesson.technique} wrote centre notes');
        }
      }
    });

    test('the whole thing undoes in one step', () async {
      final lesson = _firstLesson(
        (l) => !l.isPlacement && l.step.eliminations.isNotEmpty,
      );

      final controller = _controllerFor(lesson!.step);
      controller.gameState.activeLesson = lesson;

      await controller.applyLesson();

      var afterApply = 0;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          afterApply += controller.gameState.grid[r][c].centerNotes.length +
              controller.gameState.grid[r][c].sideNotes.length;
        }
      }
      expect(afterApply, greaterThan(0));

      await controller.undo();

      var afterUndo = 0;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          afterUndo += controller.gameState.grid[r][c].centerNotes.length +
              controller.gameState.grid[r][c].sideNotes.length;
        }
      }
      expect(afterUndo, 0,
          reason: 'one undo should retract the entire hint, notes included');
    });

    test('existing player notes are not destroyed', () async {
      final lesson = _firstLesson(
        (l) => !l.isPlacement && l.step.eliminations.isNotEmpty,
      );

      final controller = _controllerFor(lesson!.step);
      final step = lesson!.step;

      // Pick an empty cell the lesson does not eliminate from, and give it a
      // note the player supposedly wrote.
      final untouched = step.eliminations.first.cell;
      final safeCell = controller.gameState.grid
          .expand((row) => row)
          .firstWhere((c) =>
              c.number == null &&
              !c.isGiven &&
              !(c.row == untouched.row && c.col == untouched.col));

      controller.gameState.grid[safeCell.row][safeCell.col] =
          safeCell.copyWith(centerNotes: {1, 2, 3}, sideNotes: {9});

      controller.gameState.activeLesson = lesson;
      await controller.applyLesson();

      final after = controller.gameState.grid[safeCell.row][safeCell.col];
      expect(after.centerNotes, containsAll([1, 2, 3]));
      expect(after.sideNotes, contains(9));
    });
  });
}
