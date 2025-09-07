import '../models/sudoku_cell.dart';
import '../models/input_mode.dart';

class GameLogicService {
  static void applyCellAction(SudokuCell cell, int number, InputMode mode) {
    switch (mode) {
      case InputMode.normal:
        cell.digit = number;
        cell.cornerMarks.clear();
        cell.centerMarks.clear();
        break;
      case InputMode.corner:
      case InputMode.sideNotes:
        if (cell.cornerMarks.contains(number)) {
          cell.cornerMarks.remove(number);
        } else {
          cell.cornerMarks.add(number);
          cell.centerMarks.remove(number);
        }
        break;
      case InputMode.center:
      case InputMode.centerNotes:
        if (cell.centerMarks.contains(number)) {
          cell.centerMarks.remove(number);
        } else {
          cell.centerMarks.add(number);
          cell.cornerMarks.remove(number);
        }
        break;
      case InputMode.color:
      case InputMode.coloring:
        cell.colorHighlight = cell.colorHighlight == number ? 0 : number;
        break;
    }
  }

  static void undoCellAction(SudokuCell cell, int number, InputMode mode) {
    switch (mode) {
      case InputMode.normal:
        cell.digit = null;
        break;
      case InputMode.corner:
      case InputMode.sideNotes:
        if (cell.cornerMarks.contains(number)) {
          cell.cornerMarks.remove(number);
        } else {
          cell.cornerMarks.add(number);
        }
        break;
      case InputMode.center:
      case InputMode.centerNotes:
        if (cell.centerMarks.contains(number)) {
          cell.centerMarks.remove(number);
        } else {
          cell.centerMarks.add(number);
        }
        break;
      case InputMode.color:
      case InputMode.coloring:
        cell.colorHighlight = cell.colorHighlight == number ? 0 : number;
        break;
    }
  }

  static void detectConflicts(List<List<SudokuCell>> grid) {
    // Clear all conflicts first
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        grid[r][c].hasConflict = false;
      }
    }

    // Check for conflicts
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = grid[r][c];
        if (cell.digit != null) {
          _checkCellConflicts(r, c, cell.digit!, grid);
        }
      }
    }
  }

  static void _checkCellConflicts(int row, int col, int digit, List<List<SudokuCell>> grid) {
    // Check row
    for (int c = 0; c < 9; c++) {
      if (c != col && grid[row][c].digit == digit) {
        grid[row][col].hasConflict = true;
        grid[row][c].hasConflict = true;
      }
    }

    // Check column
    for (int r = 0; r < 9; r++) {
      if (r != row && grid[r][col].digit == digit) {
        grid[row][col].hasConflict = true;
        grid[r][col].hasConflict = true;
      }
    }

    // Check 3x3 box
    final boxR = (row ~/ 3) * 3;
    final boxC = (col ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if ((r != row || c != col) && grid[r][c].digit == digit) {
          grid[row][col].hasConflict = true;
          grid[r][c].hasConflict = true;
        }
      }
    }
  }
}