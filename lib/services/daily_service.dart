import 'package:shared_preferences/shared_preferences.dart';

import '../data/realm_config.dart';
import '../models/daily_puzzle.dart';

/// Serves the Puzzle of the Day.
///
/// Every day brings a *different rule* — the Daily rotates through the game's
/// variant realms (Kropki, XV, Thermo, German Whispers, Sandwich) rather than
/// serving a plain classic grid. Each week is a fixed set of seven, ordered
/// gentlest on Monday to hardest on Sunday, and the whole thing is deterministic
/// from the date, so every device shows the same puzzle on the same day with no
/// server involved.
class DailyService {
  DailyService._();

  static const String _solvedKey = 'daily_solved_days';

  /// The rule types the Daily draws from, in rotation. Classic is deliberately
  /// left out — a plain grid is a dull puzzle of the day.
  static const List<String> _types = [
    'kropki',
    'xv',
    'thermo',
    'german',
    'sandwich',
  ];

  /// The seven daily difficulty targets, Monday to Sunday. A gentle start that
  /// climbs to a proper weekend challenge.
  static const List<int> _dayTargets = [1, 2, 4, 5, 6, 8, 10];

  static const Map<String, String> _realmForType = {
    'kropki': RealmConfig.kropkiForest,
    'xv': RealmConfig.xvSkyIslands,
    'thermo': RealmConfig.thermoDesert,
    'german': RealmConfig.germanWhispers,
    'sandwich': RealmConfig.aquaLabyrinth,
  };

  /// Puzzles grouped by rule type, each list sorted by difficulty. Built once
  /// from the game's own solution-backed sets.
  static Map<String, List<DailyPuzzle>>? _byType;

  static Future<void> _ensureLoaded() async {
    if (_byType != null) return;

    final byType = <String, List<DailyPuzzle>>{};
    for (final type in _types) {
      final realm = _realmForType[type]!;
      final list = RealmConfig.getPuzzlesForRealm(realm)
          .where((p) => p.solution != null)
          .map((p) => DailyPuzzle.owned(puzzle: p, type: type))
          .toList()
        ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
      byType[type] = list;
    }
    _byType = byType;
  }

  /// No external attribution: the Daily uses the game's own puzzles. Kept so the
  /// screen can ask without special-casing.
  static Future<String> attribution() async => '';

  /// The seven puzzles for the week containing [date], Monday-first, ordered
  /// easiest to hardest. Deterministic from the week, and rotated so different
  /// weeks draw different puzzles and rule types.
  static Future<List<DailyPuzzle>> weekOf(DateTime date) async {
    await _ensureLoaded();

    final weekIndex = _weekNumber(_monday(date));
    final used = <String>{};
    final week = <DailyPuzzle>[];

    for (var i = 0; i < 7; i++) {
      // Rotate the rule type by day and by week, so a week feels varied and no
      // two weeks line up.
      final type = _types[(weekIndex + i) % _types.length];
      final target = _dayTargets[i];
      final rotation = weekIndex + i * 7;
      final pick = _pick(type, target, rotation, used);
      if (pick == null) continue;
      used.add(pick.id);
      week.add(pick);
    }

    // Gentlest first, so Monday is the kindest day and the week ramps up.
    week.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return week;
  }

  /// Picks a puzzle of [type] near [target] difficulty, avoiding ids already
  /// [used] this week and rotating the choice by [rotation] so it varies week to
  /// week. Widens the difficulty window until something fits.
  static DailyPuzzle? _pick(
    String type,
    int target,
    int rotation,
    Set<String> used,
  ) {
    final list = _byType?[type] ?? const [];
    if (list.isEmpty) return null;

    for (var window = 0; window <= 9; window++) {
      final candidates = list
          .where((p) =>
              (p.difficulty - target).abs() <= window && !used.contains(p.id))
          .toList();
      if (candidates.isNotEmpty) {
        return candidates[rotation % candidates.length];
      }
    }

    // Everything of this type is already used this week — fall back to the one
    // closest to the target, ignoring the used set.
    final byDistance = [...list]
      ..sort((a, b) => (a.difficulty - target)
          .abs()
          .compareTo((b.difficulty - target).abs()));
    return byDistance[rotation % byDistance.length];
  }

  /// Today's puzzle: the entry for today's weekday within this week's set.
  static Future<DailyPuzzle?> today([DateTime? now]) async {
    final date = now ?? DateTime.now();
    return puzzleFor(date);
  }

  /// The puzzle assigned to a specific [date] — the entry for that weekday within
  /// its week's set. Used to replay earlier days in the current week.
  static Future<DailyPuzzle?> puzzleFor(DateTime date) async {
    final week = await weekOf(date);
    if (week.isEmpty) return null;

    // Monday = 0 … Sunday = 6.
    final dayIndex = date.weekday - 1;
    return week[dayIndex % week.length];
  }

  /// The seven calendar dates of the week containing [date], Monday-first.
  static List<DateTime> weekDates(DateTime date) {
    final monday = _monday(date);
    return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
  }

  // ---------------------------------------------------------------------------
  // COMPLETION & STREAK
  // ---------------------------------------------------------------------------

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Future<Set<String>> _solvedDays() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_solvedKey) ?? const []).toSet();
  }

  static Future<bool> isSolved(DateTime date) async =>
      (await _solvedDays()).contains(_dayKey(date));

  static Future<void> markSolved(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final days = (await _solvedDays())..add(_dayKey(date));
    await prefs.setStringList(_solvedKey, days.toList());
  }

  /// Consecutive days solved up to and including today (or yesterday, so a
  /// streak survives until the day is missed).
  static Future<int> streak([DateTime? now]) async {
    final solved = await _solvedDays();
    if (solved.isEmpty) return 0;

    final today = now ?? DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);

    // Allow today to be unsolved without breaking a run that reached yesterday.
    if (!solved.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var count = 0;
    while (solved.contains(_dayKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static DateTime _monday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// A stable week index from an epoch Monday, for rotating the weekly slice.
  static int _weekNumber(DateTime monday) {
    final epoch = DateTime(2024, 1, 1); // an arbitrary fixed anchor
    return monday.difference(epoch).inDays ~/ 7;
  }
}
