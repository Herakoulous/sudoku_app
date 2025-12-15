import '../models/position.dart';
import '../models/hodoku_hint.dart';

class HoDoKuHintParser {
  static HoDoKuHint? parse(String hintString) {
    try {
      final parts = hintString.split(':');
      if (parts.length < 2) return null;

      final techniqueName = parts[0].trim();
      final notation = parts.sublist(1).join(':').trim();

      final difficulty = _getDifficulty(techniqueName);

      if (_isDirectPlacement(techniqueName)) {
        return _parseDirectPlacement(techniqueName, notation, difficulty);
      } else if (_isElimination(techniqueName)) {
        return _parseElimination(techniqueName, notation, difficulty);
      }

      return null;
    } catch (e) {
      print('❌ Error parsing HoDoKu hint: $e');
      return null;
    }
  }

  static bool _isDirectPlacement(String technique) {
    final directTechniques = [
      'Naked Single',
      'Hidden Single',
      'Full House',
    ];
    return directTechniques.any((t) => technique.contains(t));
  }

  static bool _isElimination(String technique) {
    return technique.contains('Locked') ||
        technique.contains('Pair') ||
        technique.contains('Triple') ||
        technique.contains('Wing') ||
        technique.contains('Chain') ||
        technique.contains('Fish') ||
        technique.contains('Rectangle') ||
        technique.contains('Uniqueness') ||
        technique.contains('ALS') ||
        technique.contains('AIC') ||
        technique.contains('Loop') ||
        technique.contains('Sue de Coq') ||
        technique.contains('Colors') ||
        technique.contains('Forcing');
  }

  static HoDoKuHint _parseDirectPlacement(
    String technique,
    String notation,
    HoDoKuDifficulty difficulty,
  ) {
    final match = RegExp(r'r(\d)c(\d)=(\d)').firstMatch(notation);

    if (match == null) {
      throw Exception('Cannot parse direct placement: $notation');
    }

    final row = int.parse(match.group(1)!) - 1;
    final col = int.parse(match.group(2)!) - 1;
    final number = int.parse(match.group(3)!);

    final cellPos = Position(row, col);

    return HoDoKuHint(
      techniqueName: technique,
      rawNotation: notation,
      difficulty: difficulty,
      cellToFill: cellPos,
      numberToFill: number,
      highlightCells: {cellPos},
      highlightNumbers: {number},
      eliminations: [],
      briefExplanation: 'Place $number in row ${row + 1}, column ${col + 1}',
      stepByStepExplanation: _generateDirectPlacementSteps(
        technique,
        cellPos,
        number,
      ),
    );
  }

  static HoDoKuHint _parseElimination(
    String technique,
    String notation,
    HoDoKuDifficulty difficulty,
  ) {
    final highlightCells = <Position>{};
    final highlightNumbers = <int>{};
    final eliminations = <CellElimination>[];

    final parts = notation.split('=>');
    final patternPart = parts[0].trim();
    final eliminationPart = parts.length > 1 ? parts[1].trim() : '';

    final numbers = _extractNumbers(patternPart);
    highlightNumbers.addAll(numbers);

    final patternCells = _extractCells(patternPart);
    highlightCells.addAll(patternCells);

    if (eliminationPart.isNotEmpty) {
      final eliminationList = _parseEliminationNotation(eliminationPart);
      eliminations.addAll(eliminationList);
    }

    return HoDoKuHint(
      techniqueName: technique,
      rawNotation: notation,
      difficulty: difficulty,
      cellToFill: null,
      numberToFill: null,
      highlightCells: highlightCells,
      highlightNumbers: highlightNumbers,
      eliminations: eliminations,
      briefExplanation:
          _generateBriefExplanation(technique, numbers, eliminations),
      stepByStepExplanation: _generateEliminationSteps(
        technique,
        patternPart,
        eliminations,
      ),
    );
  }

  static Set<int> _extractNumbers(String text) {
    final numbers = <int>{};
    final matches = RegExp(r'\b([1-9])\b').allMatches(text);
    for (final match in matches) {
      numbers.add(int.parse(match.group(1)!));
    }
    return numbers;
  }

  static Set<Position> _extractCells(String text) {
    final cells = <Position>{};

    final singleCellMatches = RegExp(r'r(\d)c(\d)').allMatches(text);
    for (final match in singleCellMatches) {
      final row = int.parse(match.group(1)!) - 1;
      final col = int.parse(match.group(2)!) - 1;
      cells.add(Position(row, col));
    }

    final multiCellMatches = RegExp(r'r(\d+)c(\d)').allMatches(text);
    for (final match in multiCellMatches) {
      final rowsStr = match.group(1)!;
      final col = int.parse(match.group(2)!) - 1;

      for (int i = 0; i < rowsStr.length; i++) {
        final row = int.parse(rowsStr[i]) - 1;
        cells.add(Position(row, col));
      }
    }

    return cells;
  }

  static List<CellElimination> _parseEliminationNotation(String notation) {
    final eliminations = <CellElimination>[];

    final parts = notation.split(',').map((s) => s.trim()).toList();

    for (final part in parts) {
      final match = RegExp(r'r(\d+)c(\d+)<>(\d+)').firstMatch(part);

      if (match != null) {
        final rowsStr = match.group(1)!;
        final colsStr = match.group(2)!;
        final candidate = int.parse(match.group(3)!);

        final rows = rowsStr.split('').map((c) => int.parse(c) - 1).toList();
        final cols = colsStr.split('').map((c) => int.parse(c) - 1).toList();

        for (final row in rows) {
          for (final col in cols) {
            eliminations.add(CellElimination(
              cell: Position(row, col),
              eliminatedCandidates: {candidate},
              reason: 'Eliminated by pattern',
            ));
          }
        }
      }
    }

    return eliminations;
  }

  static HoDoKuDifficulty _getDifficulty(String technique) {
    if (technique.contains('Naked Single') ||
        technique.contains('Hidden Single') ||
        technique.contains('Full House')) {
      return HoDoKuDifficulty.BEGINNER;
    }

    if (technique.contains('Locked Candidates') ||
        technique.contains('Locked Pair') ||
        technique.contains('Naked Pair') ||
        technique.contains('Hidden Pair')) {
      return HoDoKuDifficulty.EASY;
    }

    if (technique.contains('Naked Triple') ||
        technique.contains('Hidden Triple') ||
        technique.contains('Locked Triple') ||
        technique.contains('X-Wing') ||
        technique.contains('Skyscraper') ||
        technique.contains('2-String Kite') ||
        technique.contains('Empty Rectangle')) {
      return HoDoKuDifficulty.MEDIUM;
    }

    if (technique.contains('Swordfish') ||
        technique.contains('XY-Wing') ||
        technique.contains('XYZ-Wing') ||
        technique.contains('W-Wing') ||
        technique.contains('Uniqueness') ||
        technique.contains('Rectangle') ||
        technique.contains('Remote Pair') ||
        technique.contains('Turbot Fish')) {
      return HoDoKuDifficulty.HARD;
    }

    return HoDoKuDifficulty.EXTREME;
  }

  static String _generateBriefExplanation(
    String technique,
    Set<int> numbers,
    List<CellElimination> eliminations,
  ) {
    final numStr = numbers.isNotEmpty ? numbers.join(', ') : '';
    final eliminationCount = eliminations.length;

    if (eliminationCount == 1) {
      final elim = eliminations.first;
      return 'Remove ${elim.eliminatedCandidates.join(', ')} from row ${elim.cell.row + 1}, column ${elim.cell.col + 1}';
    } else if (eliminationCount > 1) {
      return 'Remove candidates from $eliminationCount cells using $technique';
    }

    return 'Apply $technique with ${numStr.isNotEmpty ? "number(s) $numStr" : ""}';
  }

  static List<String> _generateDirectPlacementSteps(
    String technique,
    Position cell,
    int number,
  ) {
    final steps = <String>[];
    final row = cell.row + 1;
    final col = cell.col + 1;

    if (technique.contains('Naked Single')) {
      steps.add('Look at row $row, column $col. Only $number can go here.');
      steps.add('All other numbers are blocked by the row, column, or box.');
    } else if (technique.contains('Hidden Single')) {
      steps.add('Scan where $number can go in this region.');
      steps.add('$number has only one valid spot - this cell!');
    } else if (technique.contains('Full House')) {
      steps.add('This region has 8 numbers placed.');
      steps.add('Fill in the missing number: $number.');
    }

    return steps;
  }

  static List<String> _generateEliminationSteps(
    String technique,
    String pattern,
    List<CellElimination> eliminations,
  ) {
    final steps = <String>[];

    if (technique.contains('Locked Candidates Type 1') ||
        technique.contains('Pointing')) {
      steps.add('A number appears only in one row/column within a box.');
      steps.add(
          'Eliminate it from the rest of that row/column outside the box.');
    } else if (technique.contains('Locked Candidates Type 2') ||
        technique.contains('Claiming')) {
      steps.add('A number appears only in one box within a row/column.');
      steps.add('Eliminate it from the rest of that box.');
    } else if (technique.contains('Naked Pair')) {
      steps.add('Two cells have the same two candidates.');
      steps
          .add('These numbers must go in these cells - eliminate from others.');
    } else if (technique.contains('X-Wing')) {
      steps.add('A number appears twice in two rows, aligned in columns.');
      steps.add('Forms a rectangle - eliminate from the columns.');
    } else if (technique.contains('XY-Wing')) {
      steps.add('Three cells form Y-shape with specific candidates.');
      steps.add('Logical chain eliminates candidates at intersection.');
    } else {
      steps.add('This pattern restricts where numbers can be placed.');
    }

    if (eliminations.isNotEmpty) {
      steps.add('Eliminate candidates from ${eliminations.length} cell(s).');
    }

    return steps;
  }
}
