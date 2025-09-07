// services/game_logic_service.dart
import '../models/sudoku_cell.dart';
import '../models/input_mode.dart';

class GameLogicService {
  // Cache for expensive calculations
  static final Map<String, bool> _placementCache = {};
  static final Map<String, Set<String>> _conflictCache = {};
  
  // Clear cache when grid changes significantly
  static void clearCache() {
    _placementCache.clear();
    _conflictCache.clear();
  }

  /// Apply a number input to a cell based on the current input mode
  static void applyCellAction(
    SudokuCell cell,
    int number,
    InputMode mode,
  ) {
    switch (mode) {
      case InputMode.normal:
        // Clear existing digit and marks when entering new digit
        cell.digit = number;
        cell.cornerMarks.clear();
        cell.centerMarks.clear();
        break;
      case InputMode.corner:
        // Toggle corner marks - don't clear digit
        if (cell.cornerMarks.contains(number)) {
          cell.cornerMarks.remove(number);
        } else {
          cell.cornerMarks.add(number);
          // Remove from center marks if it exists there
          cell.centerMarks.remove(number);
        }
        break;
      case InputMode.center:
        // Toggle center marks - don't clear digit
        if (cell.centerMarks.contains(number)) {
          cell.centerMarks.remove(number);
        } else {
          cell.centerMarks.add(number);
          // Remove from corner marks if it exists there
          cell.cornerMarks.remove(number);
        }
        break;
      case InputMode.color:
        // Toggle color highlighting - don't affect digit or marks
        cell.colorHighlight = cell.colorHighlight == number ? 0 : number;
        break;
      case InputMode.multiSelect:
        // Multi-select mode doesn't apply cell actions directly
        // This is handled by the UI layer
        break;
    }
    
    // Clear cache when cell changes
    clearCache();
  }

  /// Apply color to a cell (separate method for clarity)
  static void applyCellColor(SudokuCell cell, int colorIndex) {
    cell.colorHighlight = cell.colorHighlight == colorIndex ? 0 : colorIndex;
    clearCache();
  }

  /// Clear all content from a cell (except if it's a given cell)
  static void clearCell(SudokuCell cell) {
    if (!cell.isGiven) {
      cell.digit = null;
      cell.cornerMarks.clear();
      cell.centerMarks.clear();
      cell.colorHighlight = 0;
      clearCache();
    }
  }

  /// Check if the puzzle is completely solved
  static bool isPuzzleSolved(List<List<SudokuCell>> grid) {
    // Check if all cells have digits
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c].digit == null) {
          return false;
        }
      }
    }
    
    // Check if all rows, columns, and 3x3 boxes are valid
    for (int i = 0; i < 9; i++) {
      if (!_isRowValid(grid, i) || !_isColumnValid(grid, i) || !_isBoxValid(grid, i)) {
        return false;
      }
    }
    
    return true;
  }

  /// Check if a row is valid (contains digits 1-9 exactly once)
  static bool _isRowValid(List<List<SudokuCell>> grid, int row) {
    final Set<int> seen = {};
    for (int c = 0; c < 9; c++) {
      final digit = grid[row][c].digit;
      if (digit == null || digit < 1 || digit > 9 || seen.contains(digit)) {
        return false;
      }
      seen.add(digit);
    }
    return seen.length == 9;
  }

  /// Check if a column is valid (contains digits 1-9 exactly once)
  static bool _isColumnValid(List<List<SudokuCell>> grid, int col) {
    final Set<int> seen = {};
    for (int r = 0; r < 9; r++) {
      final digit = grid[r][col].digit;
      if (digit == null || digit < 1 || digit > 9 || seen.contains(digit)) {
        return false;
      }
      seen.add(digit);
    }
    return seen.length == 9;
  }

  /// Check if a 3x3 box is valid (contains digits 1-9 exactly once)
  static bool _isBoxValid(List<List<SudokuCell>> grid, int boxIndex) {
    final Set<int> seen = {};
    final startRow = (boxIndex ~/ 3) * 3;
    final startCol = (boxIndex % 3) * 3;
    
    for (int r = startRow; r < startRow + 3; r++) {
      for (int c = startCol; c < startCol + 3; c++) {
        final digit = grid[r][c].digit;
        if (digit == null || digit < 1 || digit > 9 || seen.contains(digit)) {
          return false;
        }
        seen.add(digit);
      }
    }
    return seen.length == 9;
  }

  /// Get cells that are related to the selected cell (same row, column, or 3x3 box)
  static Set<String> getRelatedCells(int selectedRow, int selectedCol) {
    final related = <String>{};
    
    // Same row
    for (int c = 0; c < 9; c++) {
      if (c != selectedCol) {
        related.add('$selectedRow-$c');
      }
    }
    
    // Same column
    for (int r = 0; r < 9; r++) {
      if (r != selectedRow) {
        related.add('$r-$selectedCol');
      }
    }
    
    // Same 3x3 box
    final boxR = (selectedRow ~/ 3) * 3;
    final boxC = (selectedCol ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if (r != selectedRow || c != selectedCol) {
          related.add('$r-$c');
        }
      }
    }
    
    return related;
  }

  /// Get all cells that contain the same number as the selected number
  static Set<String> getSameNumberCells(List<List<SudokuCell>> grid, int selectedNumber) {
    final sameNumber = <String>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c].digit == selectedNumber) {
          sameNumber.add('$r-$c');
        }
      }
    }
    return sameNumber;
  }

  /// Check if a number can be placed in a specific cell without conflicts
  static bool canPlaceNumber(List<List<SudokuCell>> grid, int row, int col, int number) {
    // Check row
    for (int c = 0; c < 9; c++) {
      if (c != col && grid[row][c].digit == number) {
        return false;
      }
    }
    
    // Check column
    for (int r = 0; r < 9; r++) {
      if (r != row && grid[r][col].digit == number) {
        return false;
      }
    }
    
    // Check 3x3 box
    final boxR = (row ~/ 3) * 3;
    final boxC = (col ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if ((r != row || c != col) && grid[r][c].digit == number) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Get all possible numbers that can be placed in a specific cell
  static Set<int> getPossibleNumbers(List<List<SudokuCell>> grid, int row, int col) {
    final possible = <int>{};
    for (int number = 1; number <= 9; number++) {
      if (canPlaceNumber(grid, row, col, number)) {
        possible.add(number);
      }
    }
    return possible;
  }

  /// Check for conflicts in the current grid state
  static Map<String, List<String>> findConflicts(List<List<SudokuCell>> grid) {
    final conflicts = <String, List<String>>{};
    
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = grid[r][c];
        if (cell.digit != null) {
          final cellKey = '$r-$c';
          final conflictingCells = <String>[];
          
          // Check row conflicts
          for (int col = 0; col < 9; col++) {
            if (col != c && grid[r][col].digit == cell.digit) {
              conflictingCells.add('$r-$col');
            }
          }
          
          // Check column conflicts
          for (int row = 0; row < 9; row++) {
            if (row != r && grid[row][c].digit == cell.digit) {
              conflictingCells.add('$row-$c');
            }
          }
          
          // Check box conflicts
          final boxR = (r ~/ 3) * 3;
          final boxC = (c ~/ 3) * 3;
          for (int row = boxR; row < boxR + 3; row++) {
            for (int col = boxC; col < boxC + 3; col++) {
              if ((row != r || col != c) && grid[row][col].digit == cell.digit) {
                conflictingCells.add('$row-$col');
              }
            }
          }
          
          if (conflictingCells.isNotEmpty) {
            conflicts[cellKey] = conflictingCells;
          }
        }
      }
    }
    
    return conflicts;
  }
}