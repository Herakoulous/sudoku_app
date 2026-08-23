import '../data/puzzle_codec.dart';
import '../data/realm_config.dart';

/// One puzzle in the Daily pool.
///
/// The Daily rotates through the game's variant realms so each day brings a
/// different rule — a classic grid is too plain for a puzzle of the day. These
/// come from the app's own solution-backed sets, so [author]/[source] name the
/// game itself; when a licensed puzzle is used instead they carry its credit.
class DailyPuzzle {
  final String id;

  /// 'classic', 'kropki', … — decides which realm's rules and rendering apply.
  final String type;
  final String author;
  final String source;
  final int difficulty;

  /// The playable puzzle, decoded from the pool's compact strings.
  final PuzzleData puzzle;

  const DailyPuzzle({
    required this.id,
    required this.type,
    required this.author,
    required this.source,
    required this.difficulty,
    required this.puzzle,
  });

  /// The realm whose rules and board style this puzzle uses.
  String get realmName {
    switch (type) {
      case 'kropki':
        return RealmConfig.kropkiForest;
      case 'sandwich':
        return RealmConfig.aquaLabyrinth;
      case 'xv':
        return RealmConfig.xvSkyIslands;
      case 'thermo':
        return RealmConfig.thermoDesert;
      case 'german':
        return RealmConfig.germanWhispers;
      default:
        return RealmConfig.classicKingdom;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'kropki':
        return 'Kropki';
      case 'sandwich':
        return 'Sandwich';
      case 'xv':
        return 'XV';
      case 'thermo':
        return 'Thermo';
      case 'german':
        return 'German Whispers';
      default:
        return 'Classic';
    }
  }

  /// Builds a Daily entry from one of the game's own built-in puzzles, so the
  /// Daily can serve varied-rule boards without a separate data file.
  factory DailyPuzzle.owned({
    required PuzzleData puzzle,
    required String type,
  }) {
    return DailyPuzzle(
      id: puzzle.id,
      type: type,
      author: 'Sudoku Realms',
      source: 'Sudoku Realms',
      difficulty: puzzle.difficulty,
      puzzle: puzzle,
    );
  }

  /// Builds the playable puzzle from the pool's JSON entry.
  factory DailyPuzzle.fromJson(Map<String, dynamic> json) {
    final constraints = _encodeConstraints(
      (json['constraints'] as List<dynamic>? ?? const []),
    );

    return DailyPuzzle(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'classic',
      author: json['author'] as String? ?? 'Unknown',
      source: json['source'] as String? ?? 'janko.at',
      difficulty: json['difficulty'] as int? ?? 5,
      puzzle: PuzzleData(
        id: json['id'] as String,
        difficulty: json['difficulty'] as int? ?? 5,
        grid: json['grid'] as String,
        solution: json['solution'] as String?,
        constraints: constraints,
      ),
    );
  }

  /// Turns the pool's constraint objects into the compact string the codec
  /// decodes. Only the kropki dots are needed for the imported set.
  static String _encodeConstraints(List<dynamic> raw) {
    final tokens = <String>[];

    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final kind = entry['k'] as String?;
      final a = entry['a'] as List<dynamic>?;
      final b = entry['b'] as List<dynamic>?;
      if (kind == null || a == null || b == null) continue;

      final ca = PuzzleCodec.alphabet[(a[0] as int) * 9 + (a[1] as int)];
      final cb = PuzzleCodec.alphabet[(b[0] as int) * 9 + (b[1] as int)];
      tokens.add('$kind$ca$cb');
    }

    return tokens.join(';');
  }
}
