import '../models/game_state.dart';
import '../models/position.dart';

enum HintType {
  NAKED_SINGLE,
  HIDDEN_SINGLE,
  CHAINED_ELIMINATION,
}

class HintResult {
  final HintType type;
  final Position cell;
  final int? number;
  final String explanation;
  final Map<String, dynamic>? extraInfo;
  final Set<Position>? highlightRows;
  final Set<Position>? highlightColumns;
  final Set<Position>? highlightCells;
  final Set<int>? highlightNumbers;

  HintResult({
    required this.type,
    required this.cell,
    this.number,
    required this.explanation,
    this.extraInfo,
    this.highlightRows,
    this.highlightColumns,
    this.highlightCells,
    this.highlightNumbers,
  });
}

class HintService {
  /// Main entry point - returns the simplest logical move available
  static HintResult? getHint(GameState gameState) {
    final candidates = _initializeCandidates(gameState);

    // PRIORITY 1: Check for simple Naked Singles (only one candidate)
    final nakedSingle = _findNakedSingle(gameState, candidates);
    if (nakedSingle != null) return nakedSingle;

    // PRIORITY 2: Check for simple Hidden Singles
    final hiddenSingle = _findHiddenSingle(gameState, candidates);
    if (hiddenSingle != null) return hiddenSingle;

    // PRIORITY 3: Apply progressively harder techniques
    return _findAdvancedHint(gameState, candidates);
  }

  static HintResult? _findAdvancedHint(
      GameState gameState, Map<String, Set<int>> candidates) {
    final techniques = [
      ('Pointing Pairs', _applyPointingPairs),
      ('Box/Line Reduction', _applyBoxLineReduction),
      ('Naked Pairs', _applyNakedPairs),
      ('Hidden Pairs', _applyHiddenPairs),
      ('Naked Triples', _applyNakedTriples),
    ];

    for (final (name, technique) in techniques) {
      final steps = <String>[];
      final workingCandidates = _copyCandidates(candidates);

      technique(gameState, workingCandidates, steps);

      if (steps.isNotEmpty) {
        // Check if this technique revealed a solvable cell
        final result = _findSolvableCellAfterElimination(
            gameState, workingCandidates, steps, name);
        if (result != null) return result;
      }
    }

    return null;
  }

  static Map<String, Set<int>> _copyCandidates(Map<String, Set<int>> orig) {
    return orig.map((k, v) => MapEntry(k, Set<int>.from(v)));
  }

  // =========================================================================
  // SIMPLE TECHNIQUES (No elimination needed)
  // =========================================================================

  static HintResult? _findNakedSingle(
      GameState gameState, Map<String, Set<int>> candidates) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final key = '$row,$col';
        final cands = candidates[key];

        if (cands != null && cands.length == 1) {
          final number = cands.first;
          final highlightCells =
              _getRestrictingCellsForNakedSingle(gameState, row, col);

          return HintResult(
            type: HintType.NAKED_SINGLE,
            cell: Position(row, col),
            number: number,
            explanation:
                _buildNakedSingleExplanation(gameState, row, col, number),
            highlightCells: highlightCells,
          );
        }
      }
    }
    return null;
  }

  /// Returns the 8 cells that contain numbers restricting this cell to one candidate
  static Set<Position> _getRestrictingCellsForNakedSingle(
      GameState gameState, int row, int col) {
    final restrictingCells = <Position>{};
    final usedNumbers = <int>{};

    // Check row
    for (int c = 0; c < 9; c++) {
      if (c != col) {
        final num = gameState.grid[row][c].number;
        if (num != null && !usedNumbers.contains(num)) {
          usedNumbers.add(num);
          restrictingCells.add(Position(row, c));
        }
      }
    }

    // Check column
    for (int r = 0; r < 9; r++) {
      if (r != row) {
        final num = gameState.grid[r][col].number;
        if (num != null && !usedNumbers.contains(num)) {
          usedNumbers.add(num);
          restrictingCells.add(Position(r, col));
        }
      }
    }

    // Check box
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if (r != row || c != col) {
          final num = gameState.grid[r][c].number;
          if (num != null && !usedNumbers.contains(num)) {
            usedNumbers.add(num);
            restrictingCells.add(Position(r, c));
          }
        }
      }
    }

    return restrictingCells;
  }

  static HintResult? _findHiddenSingle(
      GameState gameState, Map<String, Set<int>> candidates) {
    // Check rows
    for (int row = 0; row < 9; row++) {
      for (int num = 1; num <= 9; num++) {
        final positions = <int>[];
        for (int col = 0; col < 9; col++) {
          if (candidates['$row,$col']?.contains(num) ?? false) {
            positions.add(col);
          }
        }
        if (positions.length == 1) {
          final col = positions.first;
          final highlightCells = _getRestrictingCellsForHiddenSingle(
              gameState, candidates, row, col, num, 'row');
          return HintResult(
            type: HintType.HIDDEN_SINGLE,
            cell: Position(row, col),
            number: num,
            explanation: _buildHiddenSingleExplanation(
                row, col, num, 'Row ${row + 1}', highlightCells),
            highlightCells: highlightCells,
          );
        }
      }
    }

    // Check columns
    for (int col = 0; col < 9; col++) {
      for (int num = 1; num <= 9; num++) {
        final positions = <int>[];
        for (int row = 0; row < 9; row++) {
          if (candidates['$row,$col']?.contains(num) ?? false) {
            positions.add(row);
          }
        }
        if (positions.length == 1) {
          final row = positions.first;
          final highlightCells = _getRestrictingCellsForHiddenSingle(
              gameState, candidates, row, col, num, 'column');
          return HintResult(
            type: HintType.HIDDEN_SINGLE,
            cell: Position(row, col),
            number: num,
            explanation: _buildHiddenSingleExplanation(
                row, col, num, 'Column ${col + 1}', highlightCells),
            highlightCells: highlightCells,
          );
        }
      }
    }

    // Check boxes
    for (int box = 0; box < 9; box++) {
      final boxRow = (box ~/ 3) * 3;
      final boxCol = (box % 3) * 3;

      for (int num = 1; num <= 9; num++) {
        final positions = <Position>[];
        for (int r = boxRow; r < boxRow + 3; r++) {
          for (int c = boxCol; c < boxCol + 3; c++) {
            if (candidates['$r,$c']?.contains(num) ?? false) {
              positions.add(Position(r, c));
            }
          }
        }
        if (positions.length == 1) {
          final pos = positions.first;
          final highlightCells = _getRestrictingCellsForHiddenSingle(
              gameState, candidates, pos.row, pos.col, num, 'box');
          return HintResult(
            type: HintType.HIDDEN_SINGLE,
            cell: pos,
            number: num,
            explanation: _buildHiddenSingleExplanation(
                pos.row, pos.col, num, 'Box ${box + 1}', highlightCells),
            highlightCells: highlightCells,
          );
        }
      }
    }

    return null;
  }

  /// Returns the cells containing `num` that block it from other cells in the unit
  static Set<Position> _getRestrictingCellsForHiddenSingle(
    GameState gameState,
    Map<String, Set<int>> candidates,
    int targetRow,
    int targetCol,
    int num,
    String unitType,
  ) {
    final restrictingCells = <Position>{};

    if (unitType == 'row') {
      // For each empty cell in the row (except target), find what blocks `num`
      for (int col = 0; col < 9; col++) {
        if (col != targetCol && gameState.grid[targetRow][col].number == null) {
          // This cell can't have `num` - find the cell that blocks it
          final blocker = _findBlockingCell(gameState, targetRow, col, num);
          if (blocker != null) restrictingCells.add(blocker);
        }
      }
    } else if (unitType == 'column') {
      // For each empty cell in the column (except target), find what blocks `num`
      for (int row = 0; row < 9; row++) {
        if (row != targetRow && gameState.grid[row][targetCol].number == null) {
          final blocker = _findBlockingCell(gameState, row, targetCol, num);
          if (blocker != null) restrictingCells.add(blocker);
        }
      }
    } else if (unitType == 'box') {
      // For each empty cell in the box (except target), find what blocks `num`
      final boxRow = (targetRow ~/ 3) * 3;
      final boxCol = (targetCol ~/ 3) * 3;
      for (int r = boxRow; r < boxRow + 3; r++) {
        for (int c = boxCol; c < boxCol + 3; c++) {
          if ((r != targetRow || c != targetCol) &&
              gameState.grid[r][c].number == null) {
            final blocker = _findBlockingCell(gameState, r, c, num);
            if (blocker != null) restrictingCells.add(blocker);
          }
        }
      }
    }

    return restrictingCells;
  }

  /// Finds the cell containing `num` that blocks it from being placed at (row, col)
  static Position? _findBlockingCell(
      GameState gameState, int row, int col, int num) {
    // Check row
    for (int c = 0; c < 9; c++) {
      if (gameState.grid[row][c].number == num) {
        return Position(row, c);
      }
    }

    // Check column
    for (int r = 0; r < 9; r++) {
      if (gameState.grid[r][col].number == num) {
        return Position(r, col);
      }
    }

    // Check box
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if (gameState.grid[r][c].number == num) {
          return Position(r, c);
        }
      }
    }

    return null;
  }

  static String _buildHiddenSingleExplanation(
      int row, int col, int num, String unit, Set<Position> blockers) {
    final sb = StringBuffer();
    sb.writeln(
        'In $unit, the number $num can only go in Row ${row + 1}, Column ${col + 1}.\n');
    sb.writeln(
        'The following cells containing $num block it from other positions:');

    for (final blocker in blockers) {
      sb.writeln(
          '• ($num) at Row ${blocker.row + 1}, Column ${blocker.col + 1}');
    }

    return sb.toString();
  }

  static String _buildNakedSingleExplanation(
      GameState gameState, int row, int col, int number) {
    final usedInRow = <int>[];
    final usedInCol = <int>[];
    final usedInBox = <int>[];

    for (int c = 0; c < 9; c++) {
      final n = gameState.grid[row][c].number;
      if (n != null && c != col) usedInRow.add(n);
    }

    for (int r = 0; r < 9; r++) {
      final n = gameState.grid[r][col].number;
      if (n != null && r != row) usedInCol.add(n);
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        final n = gameState.grid[r][c].number;
        if (n != null && !(r == row && c == col)) usedInBox.add(n);
      }
    }

    usedInRow.sort();
    usedInCol.sort();
    usedInBox.sort();

    return 'At Row ${row + 1}, Column ${col + 1}:\n'
        '• Row ${row + 1} contains: ${usedInRow.join(", ")}\n'
        '• Column ${col + 1} contains: ${usedInCol.join(", ")}\n'
        '• Box contains: ${usedInBox.join(", ")}\n\n'
        'The only number not eliminated is $number.';
  }

  // =========================================================================
  // CANDIDATE INITIALIZATION
  // =========================================================================

  static Map<String, Set<int>> _initializeCandidates(GameState gameState) {
    final Map<String, Set<int>> candidates = {};

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = gameState.grid[row][col];
        final key = '$row,$col';

        if (cell.number != null) {
          candidates[key] = {};
        } else {
          candidates[key] = _computeCandidates(gameState, row, col);
        }
      }
    }

    return candidates;
  }

  static Set<int> _computeCandidates(GameState gameState, int row, int col) {
    Set<int> candidates = {1, 2, 3, 4, 5, 6, 7, 8, 9};

    for (int c = 0; c < 9; c++) {
      final num = gameState.grid[row][c].number;
      if (num != null) candidates.remove(num);
    }

    for (int r = 0; r < 9; r++) {
      final num = gameState.grid[r][col].number;
      if (num != null) candidates.remove(num);
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        final num = gameState.grid[r][c].number;
        if (num != null) candidates.remove(num);
      }
    }

    return candidates;
  }

  // =========================================================================
  // ADVANCED ELIMINATION TECHNIQUES
  // =========================================================================

  static void _applyPointingPairs(GameState gameState,
      Map<String, Set<int>> candidates, List<String> steps) {
    for (int box = 0; box < 9; box++) {
      final boxRow = (box ~/ 3) * 3;
      final boxCol = (box % 3) * 3;

      for (int num = 1; num <= 9; num++) {
        final rowsWithNum = <int>{};
        final colsWithNum = <int>{};

        for (int r = boxRow; r < boxRow + 3; r++) {
          for (int c = boxCol; c < boxCol + 3; c++) {
            if (candidates['$r,$c']?.contains(num) ?? false) {
              rowsWithNum.add(r);
              colsWithNum.add(c);
            }
          }
        }

        // If all occurrences in box are in one row
        if (rowsWithNum.length == 1 && colsWithNum.length > 1) {
          final targetRow = rowsWithNum.first;
          bool eliminated = false;

          for (int c = 0; c < 9; c++) {
            if (c < boxCol || c >= boxCol + 3) {
              final key = '$targetRow,$c';
              if (candidates[key]?.remove(num) ?? false) {
                eliminated = true;
              }
            }
          }

          if (eliminated) {
            steps.add(
                'Pointing Pair: In Box ${box + 1}, $num only appears in Row ${targetRow + 1}. Eliminated $num from other cells in Row ${targetRow + 1}.');
          }
        }

        // If all occurrences in box are in one column
        if (colsWithNum.length == 1 && rowsWithNum.length > 1) {
          final targetCol = colsWithNum.first;
          bool eliminated = false;

          for (int r = 0; r < 9; r++) {
            if (r < boxRow || r >= boxRow + 3) {
              final key = '$r,$targetCol';
              if (candidates[key]?.remove(num) ?? false) {
                eliminated = true;
              }
            }
          }

          if (eliminated) {
            steps.add(
                'Pointing Pair: In Box ${box + 1}, $num only appears in Column ${targetCol + 1}. Eliminated $num from other cells in Column ${targetCol + 1}.');
          }
        }
      }
    }
  }

  static void _applyBoxLineReduction(GameState gameState,
      Map<String, Set<int>> candidates, List<String> steps) {
    // Check rows
    for (int row = 0; row < 9; row++) {
      for (int num = 1; num <= 9; num++) {
        final boxesWithNum = <int>{};

        for (int col = 0; col < 9; col++) {
          if (candidates['$row,$col']?.contains(num) ?? false) {
            boxesWithNum.add(col ~/ 3);
          }
        }

        if (boxesWithNum.length == 1) {
          final targetBoxCol = boxesWithNum.first * 3;
          final boxRow = (row ~/ 3) * 3;
          bool eliminated = false;

          for (int r = boxRow; r < boxRow + 3; r++) {
            if (r != row) {
              for (int c = targetBoxCol; c < targetBoxCol + 3; c++) {
                if (candidates['$r,$c']?.remove(num) ?? false) {
                  eliminated = true;
                }
              }
            }
          }

          if (eliminated) {
            steps.add(
                'Box/Line Reduction: In Row ${row + 1}, $num only appears in Box ${(row ~/ 3) * 3 + boxesWithNum.first + 1}. Eliminated $num from other cells in that box.');
          }
        }
      }
    }

    // Check columns
    for (int col = 0; col < 9; col++) {
      for (int num = 1; num <= 9; num++) {
        final boxesWithNum = <int>{};

        for (int row = 0; row < 9; row++) {
          if (candidates['$row,$col']?.contains(num) ?? false) {
            boxesWithNum.add(row ~/ 3);
          }
        }

        if (boxesWithNum.length == 1) {
          final targetBoxRow = boxesWithNum.first * 3;
          final boxCol = (col ~/ 3) * 3;
          bool eliminated = false;

          for (int c = boxCol; c < boxCol + 3; c++) {
            if (c != col) {
              for (int r = targetBoxRow; r < targetBoxRow + 3; r++) {
                if (candidates['$r,$c']?.remove(num) ?? false) {
                  eliminated = true;
                }
              }
            }
          }

          if (eliminated) {
            steps.add(
                'Box/Line Reduction: In Column ${col + 1}, $num only appears in Box ${boxesWithNum.first * 3 + (col ~/ 3) + 1}. Eliminated $num from other cells in that box.');
          }
        }
      }
    }
  }

  static void _applyNakedPairs(GameState gameState,
      Map<String, Set<int>> candidates, List<String> steps) {
    for (int row = 0; row < 9; row++) {
      _applyNakedPairsInUnit(
          candidates, _getRowCells(row), 'Row ${row + 1}', steps);
    }
    for (int col = 0; col < 9; col++) {
      _applyNakedPairsInUnit(
          candidates, _getColCells(col), 'Column ${col + 1}', steps);
    }
    for (int box = 0; box < 9; box++) {
      _applyNakedPairsInUnit(
          candidates, _getBoxCells(box), 'Box ${box + 1}', steps);
    }
  }

  static void _applyNakedPairsInUnit(Map<String, Set<int>> candidates,
      List<String> cells, String unit, List<String> steps) {
    final pairCells = <String, Set<int>>{};

    for (final key in cells) {
      final cands = candidates[key];
      if (cands != null && cands.length == 2) {
        pairCells[key] = cands;
      }
    }

    final keys = pairCells.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      for (int j = i + 1; j < keys.length; j++) {
        final set1 = pairCells[keys[i]]!;
        final set2 = pairCells[keys[j]]!;

        if (set1.length == 2 &&
            set1.containsAll(set2) &&
            set2.containsAll(set1)) {
          final pairNums = set1.toList()..sort();
          bool eliminated = false;

          for (final key in cells) {
            if (key != keys[i] && key != keys[j]) {
              final cands = candidates[key];
              if (cands != null) {
                for (final num in pairNums) {
                  if (cands.remove(num)) eliminated = true;
                }
              }
            }
          }

          if (eliminated) {
            final pos1 = _parseKey(keys[i]);
            final pos2 = _parseKey(keys[j]);
            steps.add(
                'Naked Pair: In $unit, cells (${pos1.$1 + 1},${pos1.$2 + 1}) and (${pos2.$1 + 1},${pos2.$2 + 1}) both contain only {${pairNums.join(", ")}}. Eliminated these from other cells.');
          }
        }
      }
    }
  }

  static void _applyHiddenPairs(GameState gameState,
      Map<String, Set<int>> candidates, List<String> steps) {
    for (int row = 0; row < 9; row++) {
      _applyHiddenPairsInUnit(
          candidates, _getRowCells(row), 'Row ${row + 1}', steps);
    }
    for (int col = 0; col < 9; col++) {
      _applyHiddenPairsInUnit(
          candidates, _getColCells(col), 'Column ${col + 1}', steps);
    }
    for (int box = 0; box < 9; box++) {
      _applyHiddenPairsInUnit(
          candidates, _getBoxCells(box), 'Box ${box + 1}', steps);
    }
  }

  static void _applyHiddenPairsInUnit(Map<String, Set<int>> candidates,
      List<String> cells, String unit, List<String> steps) {
    final numLocations = <int, Set<String>>{};

    for (final key in cells) {
      final cands = candidates[key];
      if (cands != null) {
        for (final num in cands) {
          numLocations.putIfAbsent(num, () => {}).add(key);
        }
      }
    }

    for (int n1 = 1; n1 <= 9; n1++) {
      for (int n2 = n1 + 1; n2 <= 9; n2++) {
        final locs1 = numLocations[n1];
        final locs2 = numLocations[n2];

        if (locs1 != null &&
            locs2 != null &&
            locs1.length == 2 &&
            locs1.containsAll(locs2) &&
            locs2.containsAll(locs1)) {
          bool eliminated = false;

          for (final key in locs1) {
            final cands = candidates[key];
            if (cands != null && cands.length > 2) {
              final toRemove = cands.where((n) => n != n1 && n != n2).toList();
              for (final n in toRemove) {
                cands.remove(n);
                eliminated = true;
              }
            }
          }

          if (eliminated) {
            final cellList = locs1.map((k) {
              final pos = _parseKey(k);
              return '(${pos.$1 + 1},${pos.$2 + 1})';
            }).join(' and ');
            steps.add(
                'Hidden Pair: In $unit, {$n1, $n2} only appear in $cellList. Reduced those cells to only {$n1, $n2}.');
          }
        }
      }
    }
  }

  static void _applyNakedTriples(GameState gameState,
      Map<String, Set<int>> candidates, List<String> steps) {
    for (int row = 0; row < 9; row++) {
      _applyNakedTriplesInUnit(
          candidates, _getRowCells(row), 'Row ${row + 1}', steps);
    }
    for (int col = 0; col < 9; col++) {
      _applyNakedTriplesInUnit(
          candidates, _getColCells(col), 'Column ${col + 1}', steps);
    }
    for (int box = 0; box < 9; box++) {
      _applyNakedTriplesInUnit(
          candidates, _getBoxCells(box), 'Box ${box + 1}', steps);
    }
  }

  static void _applyNakedTriplesInUnit(Map<String, Set<int>> candidates,
      List<String> cells, String unit, List<String> steps) {
    // Get cells with 2-3 candidates
    final eligibleCells = <String>[];
    for (final key in cells) {
      final cands = candidates[key];
      if (cands != null && cands.length >= 2 && cands.length <= 3) {
        eligibleCells.add(key);
      }
    }

    if (eligibleCells.length < 3) return;

    // Try all combinations of 3 cells
    for (int i = 0; i < eligibleCells.length; i++) {
      for (int j = i + 1; j < eligibleCells.length; j++) {
        for (int k = j + 1; k < eligibleCells.length; k++) {
          final cell1 = eligibleCells[i];
          final cell2 = eligibleCells[j];
          final cell3 = eligibleCells[k];

          final union = <int>{
            ...candidates[cell1]!,
            ...candidates[cell2]!,
            ...candidates[cell3]!,
          };

          // Valid naked triple: 3 cells share exactly 3 candidates
          if (union.length == 3) {
            bool eliminated = false;
            final tripleNums = union.toList()..sort();

            for (final key in cells) {
              if (key != cell1 && key != cell2 && key != cell3) {
                final cands = candidates[key];
                if (cands != null) {
                  for (final num in tripleNums) {
                    if (cands.remove(num)) eliminated = true;
                  }
                }
              }
            }

            if (eliminated) {
              final pos1 = _parseKey(cell1);
              final pos2 = _parseKey(cell2);
              final pos3 = _parseKey(cell3);
              steps.add(
                  'Naked Triple: In $unit, cells (${pos1.$1 + 1},${pos1.$2 + 1}), (${pos2.$1 + 1},${pos2.$2 + 1}), (${pos3.$1 + 1},${pos3.$2 + 1}) share only {${tripleNums.join(", ")}}. Eliminated these from other cells.');
            }
          }
        }
      }
    }
  }

  // =========================================================================
  // FIND SOLVABLE CELL AFTER ELIMINATION
  // =========================================================================

  static HintResult? _findSolvableCellAfterElimination(GameState gameState,
      Map<String, Set<int>> candidates, List<String> steps, String technique) {
    // Check for naked singles
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final key = '$row,$col';
        final cands = candidates[key];

        if (cands != null && cands.length == 1) {
          final number = cands.first;
          return HintResult(
            type: HintType.CHAINED_ELIMINATION,
            cell: Position(row, col),
            number: number,
            explanation:
                _buildChainedExplanation(row, col, number, steps, technique),
          );
        }
      }
    }

    // Check for hidden singles
    for (int row = 0; row < 9; row++) {
      for (int num = 1; num <= 9; num++) {
        final cols = <int>[];
        for (int col = 0; col < 9; col++) {
          if (candidates['$row,$col']?.contains(num) ?? false) cols.add(col);
        }
        if (cols.length == 1) {
          return HintResult(
            type: HintType.CHAINED_ELIMINATION,
            cell: Position(row, cols.first),
            number: num,
            explanation: _buildChainedExplanation(
                row, cols.first, num, steps, technique),
          );
        }
      }
    }

    for (int col = 0; col < 9; col++) {
      for (int num = 1; num <= 9; num++) {
        final rows = <int>[];
        for (int row = 0; row < 9; row++) {
          if (candidates['$row,$col']?.contains(num) ?? false) rows.add(row);
        }
        if (rows.length == 1) {
          return HintResult(
            type: HintType.CHAINED_ELIMINATION,
            cell: Position(rows.first, col),
            number: num,
            explanation: _buildChainedExplanation(
                rows.first, col, num, steps, technique),
          );
        }
      }
    }

    return null;
  }

  static String _buildChainedExplanation(
      int row, int col, int number, List<String> steps, String technique) {
    final sb = StringBuffer();
    sb.writeln(
        'Using $technique to solve Row ${row + 1}, Column ${col + 1}:\n');

    for (int i = 0; i < steps.length; i++) {
      sb.writeln('${i + 1}. ${steps[i]}');
    }

    sb.writeln(
        '\nAfter this elimination, $number is the only possibility for this cell.');
    return sb.toString();
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  static (int, int) _parseKey(String key) {
    final parts = key.split(',');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  static List<String> _getRowCells(int row) =>
      List.generate(9, (col) => '$row,$col');

  static List<String> _getColCells(int col) =>
      List.generate(9, (row) => '$row,$col');

  static List<String> _getBoxCells(int box) {
    final boxRow = (box ~/ 3) * 3;
    final boxCol = (box % 3) * 3;
    return [
      for (int r = boxRow; r < boxRow + 3; r++)
        for (int c = boxCol; c < boxCol + 3; c++) '$r,$c'
    ];
  }
}
