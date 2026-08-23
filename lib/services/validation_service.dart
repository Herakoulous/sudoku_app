// File path: lib/services/validation_service.dart
import '../models/game_state.dart';
import '../models/position.dart';
import '../data/puzzles.dart';

class ValidationResult {
  final bool isValid;
  final Set<Position> wrongCells;
  final String? errorMessage;

  ValidationResult({
    required this.isValid,
    required this.wrongCells,
    this.errorMessage,
  });

  factory ValidationResult.valid() {
    return ValidationResult(
      isValid: true,
      wrongCells: {},
    );
  }

  factory ValidationResult.invalid(Set<Position> wrongCells) {
    return ValidationResult(
      isValid: false,
      wrongCells: wrongCells,
      errorMessage:
          'Please fix the ${wrongCells.length} incorrect ${wrongCells.length == 1 ? 'number' : 'numbers'} highlighted in red before getting a hint.',
    );
  }

  factory ValidationResult.noSolution() {
    return ValidationResult(
      isValid: true, // Allow hints even without solution
      wrongCells: {},
      errorMessage: null,
    );
  }
}

class ValidationService {
  /// Validates user-entered numbers against the puzzle solution
  /// Returns cells that have wrong numbers
  static ValidationResult validateUserEntries(GameState gameState) {
    print('\n🔍 ========== VALIDATE USER ENTRIES ==========');

    // Get the puzzle data with solution
    final puzzleData = Puzzles.getPuzzle(gameState.puzzleId);

    if (puzzleData == null) {
      print('⚠️ Puzzle data not found for ${gameState.puzzleId}');
      print('=============================================\n');
      return ValidationResult.noSolution();
    }

    // Check if puzzle has a solution
    if (puzzleData.solution == null) {
      print('ℹ️ Puzzle has no solution - skipping validation');
      print('=============================================\n');
      return ValidationResult.noSolution();
    }

    final solution = puzzleData.solution!;
    final wrongCells = <Position>{};

    // Check each cell
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];

        // Skip empty cells
        if (cell.number == null) continue;

        // Skip given cells (they're always correct)
        if (cell.isGiven) continue;

        // Check if user-entered number matches solution
        final correctNumber = solution[row][col];
        if (cell.number != correctNumber) {
          wrongCells.add(Position(row, col));
          print(
              '❌ Wrong number at ($row, $col): entered ${cell.number}, correct is $correctNumber');
        }
      }
    }

    if (wrongCells.isEmpty) {
      print('✅ All user entries are correct!');
      print('=============================================\n');
      return ValidationResult.valid();
    } else {
      print('⚠️ Found ${wrongCells.length} incorrect entries');
      print('=============================================\n');
      return ValidationResult.invalid(wrongCells);
    }
  }

  /// Marks cells with wrong numbers as errors in the grid
  static void markWrongCells(GameState gameState, Set<Position> wrongCells) {
    // First clear all solution-based errors
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];
        if (!cell.isGiven) {
          // Don't clear conflict errors, only solution errors
          // We'll use a different approach - just mark the wrong ones
        }
      }
    }

    // Mark the wrong cells
    for (final pos in wrongCells) {
      gameState.grid[pos.row][pos.col].isError = true;
    }
  }

  /// Clears solution validation errors (keeps conflict errors)
  static void clearValidationErrors(GameState gameState) {
    // This would need a way to distinguish between conflict errors
    // and solution errors. For now, we'll just clear all errors.
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        gameState.grid[row][col].isError = false;
      }
    }
  }
}
