import '../models/position.dart';

enum HoDoKuDifficulty {
  BEGINNER,
  EASY,
  MEDIUM,
  HARD,
  EXTREME,
}

class HoDoKuHint {
  final String techniqueName;
  final String rawNotation;
  final HoDoKuDifficulty difficulty;

  final Position? cellToFill;
  final int? numberToFill;
  final Set<Position> highlightCells;
  final Set<int> highlightNumbers;
  final List<CellElimination> eliminations;

  final String briefExplanation;
  final List<String> stepByStepExplanation;
  final String? techniqueTip;

  HoDoKuHint({
    required this.techniqueName,
    required this.rawNotation,
    required this.difficulty,
    this.cellToFill,
    this.numberToFill,
    required this.highlightCells,
    required this.highlightNumbers,
    required this.eliminations,
    required this.briefExplanation,
    required this.stepByStepExplanation,
    this.techniqueTip,
  });

  String get formattedTechniqueName {
    return techniqueName
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String get difficultyLabel {
    switch (difficulty) {
      case HoDoKuDifficulty.BEGINNER:
        return 'Beginner';
      case HoDoKuDifficulty.EASY:
        return 'Easy';
      case HoDoKuDifficulty.MEDIUM:
        return 'Medium';
      case HoDoKuDifficulty.HARD:
        return 'Hard';
      case HoDoKuDifficulty.EXTREME:
        return 'Extreme';
    }
  }

  String get difficultyEmoji {
    switch (difficulty) {
      case HoDoKuDifficulty.BEGINNER:
        return '🟢';
      case HoDoKuDifficulty.EASY:
        return '🔵';
      case HoDoKuDifficulty.MEDIUM:
        return '🟡';
      case HoDoKuDifficulty.HARD:
        return '🟠';
      case HoDoKuDifficulty.EXTREME:
        return '🔴';
    }
  }
}

class CellElimination {
  final Position cell;
  final Set<int> eliminatedCandidates;
  final String reason;

  CellElimination({
    required this.cell,
    required this.eliminatedCandidates,
    required this.reason,
  });
}
