import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/controllers/game_controller.dart';
import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/models/position.dart';

/// The first empty, non-given cell, and the digit that is wrong there.
({Position cell, int correct, int wrong}) _firstEmpty(GameController c) {
  final solution = Puzzles.getPuzzle(c.gameState.puzzleId)!.solution!;
  for (var r = 0; r < 9; r++) {
    for (var col = 0; col < 9; col++) {
      final cell = c.gameState.grid[r][col];
      if (cell.number == null && !cell.isGiven) {
        final correct = solution[r][col];
        return (
          cell: Position(r, col),
          correct: correct,
          wrong: (correct % 9) + 1,
        );
      }
    }
  }
  throw StateError('no empty cell');
}

GameController _controller() {
  final id = Puzzles.allPuzzles.keys.firstWhere((k) => k.startsWith('classic'));
  return GameController(
    puzzleId: id,
    difficulty: Puzzles.getPuzzle(id)!.difficulty,
  );
}

void main() {
  group('with show mistakes on', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'settings_show_mistakes': true});
    });

    testWidgets('a wrong digit is flagged immediately, before any conflict',
        (tester) async {
      final controller = _controller();
      final target = _firstEmpty(controller);

      controller.gameState.selectedCells
        ..clear()
        ..add(target.cell);

      // A wrong digit that does not (necessarily) duplicate anything yet.
      await controller.handleNumberInput(target.wrong);

      final cell = controller.gameState.grid[target.cell.row][target.cell.col];
      expect(cell.number, target.wrong);
      expect(cell.isError, isTrue,
          reason: 'a solution mismatch should light up at once');
    });

    testWidgets('a correct digit is not flagged', (tester) async {
      final controller = _controller();
      final target = _firstEmpty(controller);

      controller.gameState.selectedCells
        ..clear()
        ..add(target.cell);

      await controller.handleNumberInput(target.correct);

      final cell = controller.gameState.grid[target.cell.row][target.cell.col];
      expect(cell.isError, isFalse);
    });

    testWidgets('fixing a wrong digit clears the flag', (tester) async {
      final controller = _controller();
      final target = _firstEmpty(controller);

      controller.gameState.selectedCells
        ..clear()
        ..add(target.cell);

      await controller.handleNumberInput(target.wrong);
      expect(
        controller.gameState.grid[target.cell.row][target.cell.col].isError,
        isTrue,
      );

      await controller.handleNumberInput(target.correct);
      expect(
        controller.gameState.grid[target.cell.row][target.cell.col].isError,
        isFalse,
        reason: 'correcting the digit removes the mark',
      );
    });
  });

  group('with show mistakes off', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'settings_show_mistakes': false});
    });

    testWidgets('a wrong digit is not highlighted', (tester) async {
      final controller = _controller();
      final target = _firstEmpty(controller);

      controller.gameState.selectedCells
        ..clear()
        ..add(target.cell);

      await controller.handleNumberInput(target.wrong);

      final cell = controller.gameState.grid[target.cell.row][target.cell.col];
      expect(cell.number, target.wrong);
      expect(cell.isError, isFalse,
          reason: 'mistakes stay hidden when the setting is off');
    });
  });
}
