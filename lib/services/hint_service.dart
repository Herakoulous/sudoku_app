import '../models/game_state.dart';
import '../models/position.dart';

/// Hint types in priority order
enum HintType {
  NAKED_SINGLE,
  HIDDEN_SINGLE,
  CANDIDATE_CLEANUP,
  FOCUS_CELL,
}

/// Hint result object
class HintResult {
  final HintType type;
  final Position cell;
  final int? number;
  final String explanation;
  final Map<String, dynamic>? extraInfo;

  HintResult({
    required this.type,
    required this.cell,
    this.number,
    required this.explanation,
    this.extraInfo,
  });

  @override
  String toString() {
    return 'HintResult(type: $type, cell: (${cell.row}, ${cell.col}), number: $number, explanation: $explanation)';
  }
}

/// Service that analyzes the board and provides logical hints
class HintService {
  /// Main entry point - returns the next logical move
  static HintResult? getHint(GameState gameState) {
    print('\n🔍 ========== HINT SERVICE - START ==========');
    print('Analyzing board for logical hints...');

    // Priority 1: Check for Naked Singles
    print('\n1️⃣ Checking for Naked Singles...');
    final nakedSingle = _findNakedSingle(gameState);
    if (nakedSingle != null) {
      print('✅ Found Naked Single!');
      print('=========================================\n');
      return nakedSingle;
    }
    print('   No naked singles found.');

    // Priority 2: Check for Hidden Singles
    print('\n2️⃣ Checking for Hidden Singles...');
    final hiddenSingle = _findHiddenSingle(gameState);
    if (hiddenSingle != null) {
      print('✅ Found Hidden Single!');
      print('=========================================\n');
      return hiddenSingle;
    }
    print('   No hidden singles found.');

    // Priority 3: Check for Invalid Candidates in User Notes
    print('\n3️⃣ Checking for Invalid Candidates...');
    final cleanup = _findCandidateCleanup(gameState);
    if (cleanup != null) {
      print('✅ Found Invalid Candidate!');
      print('=========================================\n');
      return cleanup;
    }
    print('   No invalid candidates found.');

    // Priority 4: Suggest Focus Cell
    print('\n4️⃣ Finding best cell to focus on...');
    final focusCell = _findFocusCell(gameState);
    if (focusCell != null) {
      print('✅ Found Focus Cell!');
      print('=========================================\n');
      return focusCell;
    }

    print('\n❌ No hints available - puzzle might be complete or stuck');
    print('=========================================\n');
    return null;
  }

  // =========================================================================
  // PRIORITY 1: NAKED SINGLE
  // =========================================================================

  static HintResult? _findNakedSingle(GameState gameState) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];

        if (cell.number != null) continue;

        final candidates = _computeCandidates(gameState, row, col);

        if (candidates.length == 1) {
          final number = candidates.first;
          print('   💡 Naked Single at ($row, $col) = $number');

          // 🔥 IMPROVED: Clear explanation of why this number is the only option
          final explanation = _buildNakedSingleExplanation(
            gameState,
            row,
            col,
            number,
          );

          return HintResult(
            type: HintType.NAKED_SINGLE,
            cell: Position(row, col),
            number: number,
            explanation: explanation,
            extraInfo: {'candidates': candidates},
          );
        }
      }
    }
    return null;
  }

  static String _buildNakedSingleExplanation(
    GameState gameState,
    int row,
    int col,
    int number,
  ) {
    return '''Cell (Row ${row + 1}, Column ${col + 1}) must be $number.

All other numbers (1-9) are already in this row, column, or 3×3 box.''';
  }

  // =========================================================================
  // PRIORITY 2: HIDDEN SINGLE
  // =========================================================================

  static HintResult? _findHiddenSingle(GameState gameState) {
    // Check all rows
    for (int row = 0; row < 9; row++) {
      final hint = _findHiddenSingleInRow(gameState, row);
      if (hint != null) return hint;
    }

    // Check all columns
    for (int col = 0; col < 9; col++) {
      final hint = _findHiddenSingleInColumn(gameState, col);
      if (hint != null) return hint;
    }

    // Check all 3x3 boxes
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        final hint = _findHiddenSingleInBox(gameState, boxRow, boxCol);
        if (hint != null) return hint;
      }
    }

    return null;
  }

  static HintResult? _findHiddenSingleInRow(GameState gameState, int row) {
    for (int num = 1; num <= 9; num++) {
      bool exists = false;
      for (int col = 0; col < 9; col++) {
        if (gameState.grid[row][col].number == num) {
          exists = true;
          break;
        }
      }
      if (exists) continue;

      List<int> possibleColumns = [];
      for (int col = 0; col < 9; col++) {
        if (gameState.grid[row][col].number == null) {
          final candidates = _computeCandidates(gameState, row, col);
          if (candidates.contains(num)) {
            possibleColumns.add(col);
          }
        }
      }

      if (possibleColumns.length == 1) {
        final col = possibleColumns.first;
        print('   💡 Hidden Single in ROW $row: $num at ($row, $col)');

        // 🔥 IMPROVED: Explain why this number must go here
        final explanation =
            '''$num must go in Row ${row + 1}, Column ${col + 1}.

Here's why:
• Looking at Row ${row + 1}, the number $num is missing.
• Checking all empty cells in this row, the number $num can ONLY fit in Column ${col + 1}.
• All other cells in Row ${row + 1} either:
  - Already have $num in their column, or
  - Already have $num in their 3×3 box

Therefore, $num must go in position (Row ${row + 1}, Column ${col + 1}).''';

        return HintResult(
          type: HintType.HIDDEN_SINGLE,
          cell: Position(row, col),
          number: num,
          explanation: explanation,
          extraInfo: {'unit': 'row', 'unitIndex': row},
        );
      }
    }
    return null;
  }

  static HintResult? _findHiddenSingleInColumn(GameState gameState, int col) {
    for (int num = 1; num <= 9; num++) {
      bool exists = false;
      for (int row = 0; row < 9; row++) {
        if (gameState.grid[row][col].number == num) {
          exists = true;
          break;
        }
      }
      if (exists) continue;

      List<int> possibleRows = [];
      for (int row = 0; row < 9; row++) {
        if (gameState.grid[row][col].number == null) {
          final candidates = _computeCandidates(gameState, row, col);
          if (candidates.contains(num)) {
            possibleRows.add(row);
          }
        }
      }

      if (possibleRows.length == 1) {
        final row = possibleRows.first;
        print('   💡 Hidden Single in COLUMN $col: $num at ($row, $col)');

        // 🔥 IMPROVED: Explain why this number must go here
        final explanation =
            '''$num must go in Row ${row + 1}, Column ${col + 1}.

Here's why:
• Looking at Column ${col + 1}, the number $num is missing.
• Checking all empty cells in this column, the number $num can ONLY fit in Row ${row + 1}.
• All other cells in Column ${col + 1} either:
  - Already have $num in their row, or
  - Already have $num in their 3×3 box

Therefore, $num must go in position (Row ${row + 1}, Column ${col + 1}).''';

        return HintResult(
          type: HintType.HIDDEN_SINGLE,
          cell: Position(row, col),
          number: num,
          explanation: explanation,
          extraInfo: {'unit': 'column', 'unitIndex': col},
        );
      }
    }
    return null;
  }

  static HintResult? _findHiddenSingleInBox(
      GameState gameState, int boxRow, int boxCol) {
    final startRow = boxRow * 3;
    final startCol = boxCol * 3;

    for (int num = 1; num <= 9; num++) {
      bool exists = false;
      for (int r = startRow; r < startRow + 3; r++) {
        for (int c = startCol; c < startCol + 3; c++) {
          if (gameState.grid[r][c].number == num) {
            exists = true;
            break;
          }
        }
        if (exists) break;
      }
      if (exists) continue;

      List<Position> possibleCells = [];
      for (int r = startRow; r < startRow + 3; r++) {
        for (int c = startCol; c < startCol + 3; c++) {
          if (gameState.grid[r][c].number == null) {
            final candidates = _computeCandidates(gameState, r, c);
            if (candidates.contains(num)) {
              possibleCells.add(Position(r, c));
            }
          }
        }
      }

      if (possibleCells.length == 1) {
        final pos = possibleCells.first;
        print(
            '   💡 Hidden Single in BOX ($boxRow, $boxCol): $num at (${pos.row}, ${pos.col})');

        // 🔥 IMPROVED: Explain why this number must go here
        final boxNumber = boxRow * 3 + boxCol + 1;
        final explanation =
            '''$num must go in Row ${pos.row + 1}, Column ${pos.col + 1}.

Here's why:
• Looking at the 3×3 box (Box $boxNumber), the number $num is missing.
• Checking all empty cells in this box, the number $num can ONLY fit at Row ${pos.row + 1}, Column ${pos.col + 1}.
• All other cells in this box either:
  - Already have $num in their row, or
  - Already have $num in their column

Therefore, $num must go in position (Row ${pos.row + 1}, Column ${pos.col + 1}).''';

        return HintResult(
          type: HintType.HIDDEN_SINGLE,
          cell: pos,
          number: num,
          explanation: explanation,
          extraInfo: {'unit': 'box', 'boxRow': boxRow, 'boxCol': boxCol},
        );
      }
    }
    return null;
  }

  // =========================================================================
  // PRIORITY 3: CANDIDATE CLEANUP
  // =========================================================================

  static HintResult? _findCandidateCleanup(GameState gameState) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];

        if (cell.number != null) continue;

        final userNotes = {...cell.sideNotes, ...cell.centerNotes};
        if (userNotes.isEmpty) continue;

        final validCandidates = _computeCandidates(gameState, row, col);

        final invalidNotes = userNotes.difference(validCandidates);

        if (invalidNotes.isNotEmpty) {
          final invalidNumber = invalidNotes.first;
          print(
              '   💡 Invalid Candidate at ($row, $col): $invalidNumber should be removed');

          // 🔥 IMPROVED: Explain why this note is invalid
          final explanation =
              '''Remove $invalidNumber from cell (Row ${row + 1}, Column ${col + 1}).

Here's why $invalidNumber cannot go here:
• The number $invalidNumber already appears in Row ${row + 1}, OR
• The number $invalidNumber already appears in Column ${col + 1}, OR
• The number $invalidNumber already appears in the 3×3 box

Since $invalidNumber violates Sudoku rules, it cannot be placed in this cell. Remove this note to keep your analysis accurate.''';

          return HintResult(
            type: HintType.CANDIDATE_CLEANUP,
            cell: Position(row, col),
            number: invalidNumber,
            explanation: explanation,
            extraInfo: {'invalidCandidates': invalidNotes.toList()},
          );
        }
      }
    }
    return null;
  }

  // =========================================================================
  // PRIORITY 4: FOCUS CELL (FALLBACK)
  // =========================================================================

  static HintResult? _findFocusCell(GameState gameState) {
    Position? bestCell;
    int minCandidates = 10;
    Set<int>? bestCandidates;

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];

        if (cell.number != null) continue;

        final candidates = _computeCandidates(gameState, row, col);

        if (candidates.isEmpty) continue;

        if (candidates.length < minCandidates) {
          minCandidates = candidates.length;
          bestCell = Position(row, col);
          bestCandidates = candidates;
        }
      }
    }

    if (bestCell != null && bestCandidates != null) {
      print(
          '   💡 Focus Cell at (${bestCell.row}, ${bestCell.col}) with $minCandidates candidates: $bestCandidates');

      // 🔥 IMPROVED: Explain why this cell is a good focus point
      final explanation =
          '''Focus on cell (Row ${bestCell.row + 1}, Column ${bestCell.col + 1}).

This cell has only $minCandidates possible values: ${bestCandidates.toList()..sort()}

Why focus here:
• Cells with fewer candidates are easier to solve.
• Once you determine which number goes here, it may eliminate candidates in related cells.
• Solving constrained cells often unlocks the rest of the puzzle.

Try adding notes to this cell to narrow down the possibilities further.''';

      return HintResult(
        type: HintType.FOCUS_CELL,
        cell: bestCell,
        number: null,
        explanation: explanation,
        extraInfo: {
          'candidates': bestCandidates.toList(),
          'count': minCandidates
        },
      );
    }

    return null;
  }

  // =========================================================================
  // HELPER: COMPUTE VALID CANDIDATES FOR A CELL
  // =========================================================================

  static Set<int> _computeCandidates(GameState gameState, int row, int col) {
    Set<int> candidates = {1, 2, 3, 4, 5, 6, 7, 8, 9};

    // Remove numbers already in the same row
    for (int c = 0; c < 9; c++) {
      final num = gameState.grid[row][c].number;
      if (num != null) {
        candidates.remove(num);
      }
    }

    // Remove numbers already in the same column
    for (int r = 0; r < 9; r++) {
      final num = gameState.grid[r][col].number;
      if (num != null) {
        candidates.remove(num);
      }
    }

    // Remove numbers already in the same 3x3 box
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        final num = gameState.grid[r][c].number;
        if (num != null) {
          candidates.remove(num);
        }
      }
    }

    return candidates;
  }
}
