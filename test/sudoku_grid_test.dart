import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/controllers/game_controller.dart';
import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/models/variant_constraint.dart';
import 'package:sudoku_realms/utils/realm_theme.dart';
import 'package:sudoku_realms/widgets/sudoku_grid.dart';

/// Finds the first puzzle id in a family, so these tests keep working when the
/// puzzle set is regenerated.
String _firstIdOf(String prefix) {
  return Puzzles.allPuzzles.keys.firstWhere((id) => id.startsWith(prefix));
}

Widget _harness(GameController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 800,
        child: SingleChildScrollView(
          child: SudokuGrid(
            controller: controller,
            theme: RealmTheme.fromRealmSync('Aqua Labyrinth'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('sandwich clues', () {
    testWidgets('every clue is rendered', (tester) async {
      final id = _firstIdOf('sandwich');
      final puzzle = Puzzles.getPuzzle(id)!;

      final expected = puzzle.constraints
          .where((c) => c.type == ConstraintType.SANDWICH)
          .length;

      expect(expected, greaterThan(0), reason: 'test puzzle has no clues');

      final controller = GameController(
        puzzleId: id,
        difficulty: puzzle.difficulty,
      );

      await tester.pumpWidget(_harness(controller));
      await tester.pump();

      expect(find.byType(SandwichClueLabel), findsNWidgets(expected));
    });

    testWidgets('clues sit outside the board, not on top of it',
        (tester) async {
      final id = _firstIdOf('sandwich');
      final puzzle = Puzzles.getPuzzle(id)!;

      final controller = GameController(
        puzzleId: id,
        difficulty: puzzle.difficulty,
      );

      await tester.pumpWidget(_harness(controller));
      await tester.pump();

      final board = tester.getRect(find.byType(GridView));

      for (final element in find.byType(SandwichClueLabel).evaluate()) {
        final clue = tester.getRect(find.byWidget(element.widget));

        // A clue belongs in the left gutter or the top gutter. If it overlapped
        // the board it would be sitting on the puzzle; if it were off-screen it
        // would be invisible, which is the bug this replaced.
        final inLeftGutter = clue.right <= board.left + 0.5;
        final inTopGutter = clue.bottom <= board.top + 0.5;

        expect(
          inLeftGutter || inTopGutter,
          isTrue,
          reason: 'clue at $clue overlaps the board at $board',
        );

        expect(clue.left, greaterThanOrEqualTo(-0.5));
        expect(clue.top, greaterThanOrEqualTo(-0.5));
        expect(clue.width, greaterThan(8));
        expect(clue.height, greaterThan(8));
      }
    });

    testWidgets('no gutter is reserved for puzzles without clues',
        (tester) async {
      final id = _firstIdOf('classic');
      final puzzle = Puzzles.getPuzzle(id)!;

      final controller = GameController(
        puzzleId: id,
        difficulty: puzzle.difficulty,
      );

      await tester.pumpWidget(_harness(controller));
      await tester.pump();

      expect(find.byType(SandwichClueLabel), findsNothing);

      // The board should use the full width available inside the padding.
      final board = tester.getRect(find.byType(GridView));
      expect(board.width, closeTo(400 - 32, 0.5));
    });
  });

  group('double tap promotes a single note', () {
    late GameController controller;

    setUp(() {
      final id = _firstIdOf('classic');
      final puzzle = Puzzles.getPuzzle(id)!;
      controller = GameController(
        puzzleId: id,
        difficulty: puzzle.difficulty,
      );
    });

    /// First empty, non-given cell in the puzzle.
    ({int row, int col}) firstEmpty() {
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final cell = controller.gameState.grid[r][c];
          if (cell.number == null && !cell.isGiven) return (row: r, col: c);
        }
      }
      throw StateError('puzzle has no empty cells');
    }

    test('a lone centre note becomes the answer', () async {
      final target = firstEmpty();
      final cell = controller.gameState.grid[target.row][target.col];
      controller.gameState.grid[target.row][target.col] =
          cell.copyWith(centerNotes: {7});

      await controller.promoteSingleNote(target.row, target.col);

      final after = controller.gameState.grid[target.row][target.col];
      expect(after.number, 7);
      expect(after.centerNotes, isEmpty);
      expect(after.sideNotes, isEmpty);
    });

    test('a lone side note becomes the answer', () async {
      final target = firstEmpty();
      final cell = controller.gameState.grid[target.row][target.col];
      controller.gameState.grid[target.row][target.col] =
          cell.copyWith(sideNotes: {4});

      await controller.promoteSingleNote(target.row, target.col);

      expect(controller.gameState.grid[target.row][target.col].number, 4);
    });

    test('two notes are left alone', () async {
      final target = firstEmpty();
      final cell = controller.gameState.grid[target.row][target.col];
      controller.gameState.grid[target.row][target.col] =
          cell.copyWith(centerNotes: {3, 8});

      await controller.promoteSingleNote(target.row, target.col);

      final after = controller.gameState.grid[target.row][target.col];
      expect(after.number, isNull);
      expect(after.centerNotes, {3, 8});
    });

    test('the same digit noted in both styles still counts as one', () async {
      final target = firstEmpty();
      final cell = controller.gameState.grid[target.row][target.col];
      controller.gameState.grid[target.row][target.col] =
          cell.copyWith(centerNotes: {5}, sideNotes: {5});

      await controller.promoteSingleNote(target.row, target.col);

      expect(controller.gameState.grid[target.row][target.col].number, 5);
    });

    test('an empty cell with no notes is left alone', () async {
      final target = firstEmpty();

      await controller.promoteSingleNote(target.row, target.col);

      expect(controller.gameState.grid[target.row][target.col].number, isNull);
    });

    test('a given cell is never overwritten', () async {
      int? gr, gc;
      for (var r = 0; r < 9 && gr == null; r++) {
        for (var c = 0; c < 9; c++) {
          if (controller.gameState.grid[r][c].isGiven) {
            gr = r;
            gc = c;
            break;
          }
        }
      }

      final before = controller.gameState.grid[gr!][gc!].number;

      await controller.promoteSingleNote(gr, gc);

      expect(controller.gameState.grid[gr][gc].number, before);
    });

    test('promotion is undoable', () async {
      final target = firstEmpty();
      final cell = controller.gameState.grid[target.row][target.col];
      controller.gameState.grid[target.row][target.col] =
          cell.copyWith(centerNotes: {6});

      await controller.promoteSingleNote(target.row, target.col);
      expect(controller.gameState.grid[target.row][target.col].number, 6);

      await controller.undo();

      final after = controller.gameState.grid[target.row][target.col];
      expect(after.number, isNull);
      expect(after.centerNotes, {6});
    });
  });
}
