// File path: lib/services/hodoku_hint_explainer.dart
import '../models/hodoku_hint.dart';

class HoDoKuHintExplainer {
  /// Format hint explanation for the bubble display (split into paragraphs)
  static List<String> formatForBubble(HoDoKuHint hint) {
    final paragraphs = <String>[];

    // Add specific action statement
    paragraphs.add(_formatActionStatement(hint));

    // Add puzzle-specific explanation
    paragraphs.addAll(_getSpecificExplanation(hint));

    // Add learning tip
    paragraphs.add(_getLearnMoreInfo(hint.techniqueName));

    return paragraphs;
  }

  /// Format full detailed explanation
  static String formatFullExplanation(HoDoKuHint hint) {
    final paragraphs = formatForBubble(hint);
    return paragraphs.join('\n\n');
  }

  static String _formatActionStatement(HoDoKuHint hint) {
    if (hint.cellToFill != null && hint.numberToFill != null) {
      final row = hint.cellToFill!.row + 1;
      final col = hint.cellToFill!.col + 1;
      return '${hint.difficultyEmoji} Place ${hint.numberToFill} in R${row}C$col!';
    } else if (hint.eliminations.isNotEmpty) {
      final candidates = <int>{};
      for (final elim in hint.eliminations) {
        candidates.addAll(elim.eliminatedCandidates);
      }

      if (hint.eliminations.length == 1) {
        final elim = hint.eliminations.first;
        final row = elim.cell.row + 1;
        final col = elim.cell.col + 1;
        final nums = elim.eliminatedCandidates.join(', ');
        return '${hint.difficultyEmoji} Eliminate $nums from R${row}C$col!';
      } else {
        return '${hint.difficultyEmoji} Eliminate ${candidates.join(', ')} from ${hint.eliminations.length} cells!';
      }
    }
    return '${hint.difficultyEmoji} Apply ${hint.techniqueName}!';
  }

  static List<String> _getSpecificExplanation(HoDoKuHint hint) {
    final technique = hint.techniqueName;
    final explanations = <String>[];

    if (technique.contains('Naked Single')) {
      if (hint.cellToFill != null && hint.numberToFill != null) {
        final row = hint.cellToFill!.row + 1;
        final col = hint.cellToFill!.col + 1;
        explanations.add(
            'Cell R${row}C$col has only one remaining candidate: ${hint.numberToFill}. All other numbers are already used in its row, column, or box.');
      }
    } else if (technique.contains('Hidden Single')) {
      if (hint.cellToFill != null && hint.numberToFill != null) {
        final row = hint.cellToFill!.row + 1;
        final col = hint.cellToFill!.col + 1;
        explanations.add(
            'Looking at where ${hint.numberToFill} can go in this region, R${row}C$col is the only valid position. All other cells in the region already contain ${hint.numberToFill} or cannot have it.');
      }
    } else if (technique.contains('Full House')) {
      if (hint.cellToFill != null && hint.numberToFill != null) {
        final row = hint.cellToFill!.row + 1;
        final col = hint.cellToFill!.col + 1;
        explanations.add(
            'Eight cells are filled in this region. The last empty cell at R${row}C$col must be ${hint.numberToFill}.');
      }
    } else if (technique.contains('Locked Candidates Type 1') ||
        technique.contains('Pointing')) {
      _explainLockedCandidatesPointing(hint, explanations);
    } else if (technique.contains('Locked Candidates Type 2') ||
        technique.contains('Claiming')) {
      _explainLockedCandidatesClaiming(hint, explanations);
    } else if (technique.contains('Locked Pair')) {
      _explainLockedPair(hint, explanations);
    } else if (technique.contains('Naked Pair')) {
      _explainNakedPair(hint, explanations);
    } else if (technique.contains('Hidden Pair')) {
      _explainHiddenPair(hint, explanations);
    } else if (technique.contains('Naked Triple')) {
      _explainNakedTriple(hint, explanations);
    } else if (technique.contains('Hidden Triple')) {
      _explainHiddenTriple(hint, explanations);
    } else if (technique.contains('X-Wing')) {
      _explainXWing(hint, explanations);
    } else if (technique.contains('Swordfish')) {
      _explainSwordfish(hint, explanations);
    } else if (technique.contains('Skyscraper')) {
      _explainSkyscraper(hint, explanations);
    } else if (technique.contains('2-String Kite')) {
      _explainKite(hint, explanations);
    } else if (technique.contains('Empty Rectangle')) {
      _explainEmptyRectangle(hint, explanations);
    } else if (technique.contains('Turbot Fish')) {
      _explainTurbotFish(hint, explanations);
    } else if (technique.contains('W-Wing')) {
      _explainWWing(hint, explanations);
    } else if (technique.contains('XYZ-Wing')) {
      _explainXYZWing(hint, explanations);
    } else if (technique.contains('XY-Wing')) {
      _explainXYWing(hint, explanations);
    } else if (technique.contains('Uniqueness')) {
      _explainUniqueness(hint, explanations);
    } else if (technique.contains('Rectangle')) {
      _explainRectangle(hint, explanations);
    } else if (technique.contains('BUG')) {
      _explainBUG(hint, explanations);
    } else if (technique.contains('Sue de Coq')) {
      _explainSueDeCoq(hint, explanations);
    } else if (technique.contains('ALS')) {
      _explainALS(hint, explanations);
    } else if (technique.contains('Chain') || technique.contains('AIC')) {
      _explainChain(hint, explanations);
    } else if (technique.contains('Loop')) {
      _explainLoop(hint, explanations);
    } else if (technique.contains('Multi Colors')) {
      _explainMultiColors(hint, explanations);
    } else if (technique.contains('Remote Pair')) {
      _explainRemotePair(hint, explanations);
    } else if (technique.contains('Forcing')) {
      _explainForcingChain(hint, explanations);
    } else {
      // Generic explanation
      _explainGeneric(hint, explanations);
    }

    return explanations;
  }

  static void _explainLockedCandidatesPointing(
      HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();
    final eliminations = hint.eliminations;

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'The candidate $num in this box is confined to a single row or column.');

      if (eliminations.isNotEmpty) {
        final eliminatedCells = eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'Since $num must be in this line within the box, we can eliminate it from the rest of that line: $eliminatedCells.');
      }
    }
  }

  static void _explainLockedCandidatesClaiming(
      HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();
    final eliminations = hint.eliminations;

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'In this row or column, the candidate $num can only appear within a single box.');

      if (eliminations.isNotEmpty) {
        final eliminatedCells = eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'This means $num must be in that box, so we can eliminate it from other cells in the box: $eliminatedCells.');
      }
    }
  }

  static void _explainLockedPair(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length >= 2) {
      explanations.add(
          'The candidates ${numbers.join(', ')} are locked together in specific cells.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations
            .add('These locked candidates eliminate from: $eliminatedCells.');
      }
    }
  }

  static void _explainNakedPair(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();
    final cells = hint.highlightCells.toList();

    if (numbers.length == 2 && cells.length >= 2) {
      final cellList =
          cells.take(2).map((c) => 'R${c.row + 1}C${c.col + 1}').join(' and ');
      explanations.add(
          'Cells $cellList both contain exactly the candidates ${numbers.join(' and ')}.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'Since ${numbers.join(' and ')} must occupy these two cells, eliminate them from: $eliminatedCells.');
      }
    }
  }

  static void _explainHiddenPair(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length >= 2) {
      explanations.add(
          'The numbers ${numbers.join(' and ')} can only appear in two specific cells within this region.');

      if (hint.eliminations.isNotEmpty) {
        explanations.add(
            'All other candidates can be removed from these two cells, leaving only ${numbers.join(' and ')}.');
      }
    }
  }

  static void _explainNakedTriple(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length == 3) {
      explanations.add(
          'Three cells contain only the candidates ${numbers.join(', ')} between them.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'These three numbers are locked to these cells. Eliminate ${numbers.join(', ')} from: $eliminatedCells.');
      }
    }
  }

  static void _explainHiddenTriple(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length >= 3) {
      explanations.add(
          'The numbers ${numbers.take(3).join(', ')} can only fit in three specific cells in this region.');
      explanations.add('Remove all other candidates from these three cells.');
    }
  }

  static void _explainXWing(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'The candidate $num appears in exactly two positions in two different rows, and these positions align in two columns (forming a rectangle).');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'We can eliminate $num from other cells in these columns: $eliminatedCells.');
      }
    }
  }

  static void _explainSwordfish(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'The candidate $num forms a 3×3 pattern across three rows and three columns.');

      if (hint.eliminations.isNotEmpty) {
        final count = hint.eliminations.length;
        explanations.add(
            'This Swordfish pattern allows us to eliminate $num from $count cells in the affected columns.');
      }
    }
  }

  static void _explainSkyscraper(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'Two rows each have exactly two positions where $num can go, forming a skyscraper pattern.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'The diagonal connection eliminates $num from: $eliminatedCells.');
      }
    }
  }

  static void _explainKite(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'A candidate $num appears twice in a row and twice in a column, connected through a box like a kite shape.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations
            .add('The kite pattern eliminates $num from: $eliminatedCells.');
      }
    }
  }

  static void _explainEmptyRectangle(
      HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'In this box, the candidate $num leaves an "empty rectangle" - one row and one column have no $num candidates.');

      if (hint.eliminations.isNotEmpty) {
        explanations.add(
            'This pattern, combined with a strong link, creates eliminations.');
      }
    }
  }

  static void _explainTurbotFish(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'Strong links with candidate $num form a chain. Following the chain: if one end is false, the other must be true.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add('This forces eliminations at: $eliminatedCells.');
      }
    }
  }

  static void _explainWWing(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length == 2) {
      explanations.add(
          'Two cells contain the same pair ${numbers.join('/')} and are connected by a strong link.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'Cells seeing both wings can eliminate the shared candidate: $eliminatedCells.');
      }
    }
  }

  static void _explainXYZWing(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length >= 3) {
      explanations.add(
          'A hinge cell contains three candidates ${numbers.take(3).join('/')}, connected to two wing cells.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'The common candidate in all three cells can be eliminated from: $eliminatedCells.');
      }
    }
  }

  static void _explainXYWing(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length >= 3) {
      explanations.add(
          'Three bivalue cells form a Y-pattern. The pivot connects two wings, creating a forcing chain.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'This eliminates from cells seeing both wings: $eliminatedCells.');
      }
    }
  }

  static void _explainUniqueness(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'Four cells form a rectangle with two candidates. If all four were bivalue, the puzzle would have multiple solutions.');

    if (hint.eliminations.isNotEmpty) {
      final eliminatedCells = hint.eliminations
          .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
          .join(', ');
      explanations.add(
          'To maintain a unique solution, we can make eliminations at: $eliminatedCells.');
    }
  }

  static void _explainRectangle(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'A deadly rectangle pattern threatens multiple solutions. We must break this pattern.');

    if (hint.eliminations.isNotEmpty) {
      explanations.add(
          'Specific candidates must be eliminated or placed to avoid the deadly pattern.');
    }
  }

  static void _explainBUG(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'The puzzle is in a Bivalue Universal Grave state - almost all cells have exactly two candidates.');

    if (hint.eliminations.isNotEmpty) {
      explanations.add(
          'Cells with three candidates break this pattern. One specific candidate must be true to maintain uniqueness.');
    }
  }

  static void _explainSueDeCoq(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'Cells at an intersection share candidates with two different regions in a locked pattern.');

    if (hint.eliminations.isNotEmpty) {
      final count = hint.eliminations.length;
      explanations.add(
          'This powerful pattern creates $count eliminations across the affected regions.');
    }
  }

  static void _explainALS(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'Almost Locked Sets interact - groups with n+1 candidates in n cells share restricted commons.');

    if (hint.eliminations.isNotEmpty) {
      final eliminatedCells = hint.eliminations
          .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
          .join(', ');
      explanations.add('This creates eliminations at: $eliminatedCells.');
    }
  }

  static void _explainChain(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'Strong links (=) and weak links (-) alternate in a chain. Strong means "one must be true", weak means "both can\'t be true".');

    if (hint.eliminations.isNotEmpty) {
      final count = hint.eliminations.length;
      explanations
          .add('Following the chain logic creates $count eliminations.');
    }
  }

  static void _explainLoop(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'A chain of alternating inferences forms a complete loop, returning to its starting point.');

    if (hint.eliminations.isNotEmpty) {
      explanations
          .add('The circular logic proves certain candidates cannot be true.');
    }
  }

  static void _explainMultiColors(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList();

    if (numbers.isNotEmpty) {
      final num = numbers.first;
      explanations.add(
          'Candidate $num is tracked in alternating color chains. When two chains interact, contradictions emerge.');

      if (hint.eliminations.isNotEmpty) {
        final eliminatedCells = hint.eliminations
            .map((e) => 'R${e.cell.row + 1}C${e.cell.col + 1}')
            .join(', ');
        explanations.add(
            'Cells seeing conflicting colors eliminate $num: $eliminatedCells.');
      }
    }
  }

  static void _explainRemotePair(HoDoKuHint hint, List<String> explanations) {
    final numbers = hint.highlightNumbers.toList()..sort();

    if (numbers.length == 2) {
      explanations.add(
          'Bivalue cells with the same two candidates ${numbers.join('/')} form a chain through strong links.');

      if (hint.eliminations.isNotEmpty) {
        explanations.add(
            'Following the chain like dominos reveals eliminations at cells seeing multiple chain points.');
      }
    }
  }

  static void _explainForcingChain(HoDoKuHint hint, List<String> explanations) {
    explanations.add(
        'Testing "what if?" scenarios: if all possible paths lead to the same result, that result is certain.');

    if (hint.cellToFill != null) {
      explanations.add('All paths prove a specific value must be placed.');
    } else if (hint.eliminations.isNotEmpty) {
      explanations
          .add('All paths prove certain candidates must be eliminated.');
    }
  }

  static void _explainGeneric(HoDoKuHint hint, List<String> explanations) {
    if (hint.highlightCells.isNotEmpty) {
      final cellCount = hint.highlightCells.length;
      explanations
          .add('This advanced pattern involves $cellCount highlighted cells.');
    }

    if (hint.highlightNumbers.isNotEmpty) {
      final numbers = hint.highlightNumbers.toList()..sort();
      explanations.add('Focus on candidates: ${numbers.join(', ')}.');
    }

    if (hint.eliminations.isNotEmpty) {
      final count = hint.eliminations.length;
      explanations.add('This technique creates $count elimination(s).');
    }
  }

  static String _getLearnMoreInfo(String technique) {
    final tips = {
      'Naked Single':
          '💡 Tip: Look for cells with the fewest candidates first.',
      'Hidden Single':
          '💡 Tip: Check each number 1-9 in every region systematically.',
      'Full House': '💡 Tip: These are freebies - fill them immediately!',
      'Locked Candidates Type 1 (Pointing)':
          '💡 Tip: Check if all candidates in a box lie on one line.',
      'Locked Candidates Type 2 (Claiming)':
          '💡 Tip: Check if all candidates in a line lie in one box.',
      'Naked Pair':
          '💡 Tip: Look for cells with exactly 2 matching candidates.',
      'Hidden Pair': '💡 Tip: Track where each number can go in each region.',
      'Locked Pair':
          '💡 Tip: Look for pairs confined to both a box and a line.',
      'Naked Triple':
          '💡 Tip: Find three cells sharing exactly three candidates.',
      'X-Wing':
          '💡 Tip: Scan for candidates appearing twice in two parallel lines.',
      'Swordfish':
          '💡 Tip: Like X-Wing but with three lines - powerful but rare.',
      'XY-Wing':
          '💡 Tip: Find a pivot cell with 2 candidates, then look for matching wings.',
      'XY-Chain':
          '💡 Tip: Chain bivalue cells sharing one candidate at a time.',
      'Uniqueness Test 1':
          '💡 Tip: Look for rectangles threatening multiple solutions.',
      'AIC':
          '💡 Tip: Master the difference between strong (=) and weak (-) links.',
      'Nice Loop': '💡 Tip: Chains that loop back prove powerful eliminations.',
      'Forcing Chain':
          '💡 Tip: If all possibilities force the same outcome, it\'s certain.',
      'Multi Colors':
          '💡 Tip: Color conjugate pairs - contradictions reveal truth.',
    };

    return tips[technique] ??
        '💡 Tip: Practice makes perfect - this gets easier with experience!';
  }
}
