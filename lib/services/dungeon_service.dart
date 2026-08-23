import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/dungeon.dart';

/// Runs ranked play: ratings, puzzle matchmaking, and the Elo maths.
///
/// Offline for now — everything lives in local storage. The rating model is
/// standard Elo with the puzzle as the opponent, so when this goes online later
/// the same numbers can be reconciled with a server without changing how it
/// feels to play.
class DungeonService {
  DungeonService._();

  static const String _ratingPrefix = 'dungeon_rating_';
  static const String _historyPrefix = 'dungeon_history_';
  static const String _logKey = 'dungeon_game_log';
  static const int _logLimit = 60;

  /// How many rating points to keep per mode for the trend chart. A cap keeps
  /// storage bounded; the chart only needs a readable recent history.
  static const int _historyLimit = 100;

  /// How many games a player is treated as "provisional". While provisional
  /// their rating moves fast, so a newcomer reaches their true level in a
  /// handful of games instead of grinding dozens.
  static const int _provisionalGames = 15;

  /// The Elo K-factor for a player who has finished [played] games.
  ///
  /// High and dropping while provisional (big swings to find your level), then
  /// settling to a steady value where one result no longer whipsaws the rating.
  static double _kFor(int played) {
    if (played >= _provisionalGames) return 24;
    // 64 down to 24 across the provisional window.
    return 64 - (64 - 24) * (played / _provisionalGames);
  }

  /// Maps a puzzle's 1–10 difficulty onto the Elo scale. Level 1 sits well below
  /// a new player (an easy win), level 10 well above (a real test).
  static int puzzleRating(int difficulty) =>
      600 + (difficulty.clamp(1, 10) - 1) * 165;

  /// Expected score for a player of [playerRating] against [puzzleRating] — the
  /// probability they solve it, in Elo terms.
  static double _expected(int playerRating, int puzzleRating) =>
      1 / (1 + math.pow(10, (puzzleRating - playerRating) / 400));

  /// The rating a win, or a loss, would produce. Exposed so the result screen
  /// can show "+18 / −12" before committing anything.
  static int projectedRating({
    required int current,
    required int difficulty,
    required bool won,
    int played = _provisionalGames,
  }) {
    final expected = _expected(current, puzzleRating(difficulty));
    final score = won ? 1.0 : 0.0;
    final next = current + (_kFor(played) * (score - expected)).round();
    // A rating floor keeps a run of losses from spiralling below the board.
    return math.max(100, next);
  }

  /// Whether the player is still finding their level, for a "placement" hint in
  /// the UI.
  static bool isProvisional(DungeonRating rating) =>
      rating.played < _provisionalGames;

  static int provisionalGamesLeft(DungeonRating rating) =>
      (_provisionalGames - rating.played).clamp(0, _provisionalGames);

  // ---------------------------------------------------------------------------
  // RATINGS
  // ---------------------------------------------------------------------------

  static Future<DungeonRating> ratingFor(DungeonMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_ratingPrefix${mode.storageKey}');
    if (raw == null) return const DungeonRating();

    try {
      return DungeonRating.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DungeonRating();
    }
  }

  static Future<Map<DungeonMode, DungeonRating>> allRatings() async {
    return {
      for (final mode in DungeonMode.values) mode: await ratingFor(mode),
    };
  }

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  /// The sequence of ratings this mode has held, oldest first, for the trend
  /// chart. Seeded with the starting rating so a single game already draws a
  /// line rather than a lone dot.
  static Future<List<int>> history(DungeonMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_historyPrefix${mode.storageKey}');
    if (raw == null || raw.isEmpty) {
      return [const DungeonRating().rating];
    }
    return [
      const DungeonRating().rating,
      for (final entry in raw)
        if (int.tryParse(entry) case final value?) value,
    ];
  }

  static Future<void> _appendHistory(
    SharedPreferences prefs,
    DungeonMode mode,
    int rating,
  ) async {
    final key = '$_historyPrefix${mode.storageKey}';
    final list = prefs.getStringList(key) ?? <String>[];
    list.add('$rating');
    if (list.length > _historyLimit) {
      list.removeRange(0, list.length - _historyLimit);
    }
    await prefs.setStringList(key, list);
  }

  // ---------------------------------------------------------------------------
  // RANKED GAME LOG (for the dungeon archive)
  // ---------------------------------------------------------------------------

  /// Puzzles played in ranked mode, newest first, so they can be revisited and
  /// replayed with hints. One entry per game; the same puzzle can appear more
  /// than once.
  static Future<List<DungeonGame>> gameLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_logKey) ?? const [];
    final out = <DungeonGame>[];
    for (final entry in raw) {
      try {
        out.add(DungeonGame.fromJson(jsonDecode(entry) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> _appendGameLog(
    SharedPreferences prefs,
    Map<String, dynamic> entry,
  ) async {
    final list = prefs.getStringList(_logKey) ?? <String>[];
    list.insert(0, jsonEncode(entry)); // newest first
    if (list.length > _logLimit) {
      list.removeRange(_logLimit, list.length);
    }
    await prefs.setStringList(_logKey, list);
  }

  /// Commits the outcome of a ranked attempt and returns the full result.
  static Future<DungeonResult> recordOutcome({
    required DungeonMode mode,
    required bool won,
    required int difficulty,
    required Duration elapsed,
    required int mistakes,
    String? puzzleId,
  }) async {
    final before = await ratingFor(mode);
    final after = projectedRating(
      current: before.rating,
      difficulty: difficulty,
      won: won,
      played: before.played,
    );

    final updated = before.copyWith(
      rating: after,
      played: before.played + 1,
      won: before.won + (won ? 1 : 0),
      streak: won ? before.streak + 1 : 0,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_ratingPrefix${mode.storageKey}',
      jsonEncode(updated.toJson()),
    );

    await _appendHistory(prefs, mode, after);

    if (puzzleId != null) {
      await _appendGameLog(prefs, {
        'id': puzzleId,
        'mode': mode.storageKey,
        'won': won,
        'difficulty': difficulty,
        'seconds': elapsed.inSeconds,
      });
    }

    return DungeonResult(
      mode: mode,
      won: won,
      puzzleDifficulty: difficulty,
      ratingBefore: before.rating,
      ratingAfter: after,
      elapsed: elapsed,
      mistakes: mistakes,
    );
  }

  // ---------------------------------------------------------------------------
  // MATCHMAKING
  // ---------------------------------------------------------------------------

  /// The difficulty that best suits the player's current rating — one step
  /// above their level, so a win is earned but reachable.
  static Future<int> suggestedDifficulty(DungeonMode mode) async {
    final rating = (await ratingFor(mode)).rating;
    return (((rating - 600) / 165 + 1).round() + 1).clamp(1, 10);
  }

  /// Picks a puzzle for a run.
  ///
  /// With [difficulty] null it matches the player's rating; otherwise it honours
  /// the level they chose. Draws from the classic pool, the only fully
  /// solution-backed set, and varies the pick so consecutive runs differ.
  static Future<PuzzleData?> matchPuzzle(
    DungeonMode mode, {
    int? difficulty,
    math.Random? random,
  }) async {
    final rng = random ?? math.Random();
    final wanted =
        (difficulty ?? await suggestedDifficulty(mode)).clamp(1, 10);

    final pool = RealmConfig.getPuzzlesForRealm(RealmConfig.classicKingdom)
        .where((p) => p.solution != null)
        .toList();
    if (pool.isEmpty) return null;

    // Widen the difficulty window until something matches, so a sparse band
    // never leaves the player with nothing to play.
    for (var window = 0; window <= 9; window++) {
      final candidates = pool
          .where((p) => (p.difficulty - wanted).abs() <= window)
          .toList();
      if (candidates.isNotEmpty) {
        return candidates[rng.nextInt(candidates.length)];
      }
    }

    return pool[rng.nextInt(pool.length)];
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final mode in DungeonMode.values) {
      await prefs.remove('$_ratingPrefix${mode.storageKey}');
      await prefs.remove('$_historyPrefix${mode.storageKey}');
    }
    await prefs.remove(_logKey);
  }
}
