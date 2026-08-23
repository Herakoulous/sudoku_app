import 'difficulty_tier.dart';
import 'solve_record.dart';

/// Everything the achievement catalogue can measure, derived once from the
/// solve log so no achievement has to touch storage itself.
///
/// Counts of *puzzles* are deduplicated by id and credit the player's best
/// attempt: re-solving the same board with a hint must never take away a
/// no-hint award they already earned.
class PlayerStats {
  final int solves;
  final Map<String, int> solvesByRealm;
  final Set<String> completedRealms;
  final int totalStars;

  final int fastestSeconds;
  final int averageSeconds;
  final int totalPlaySeconds;

  final int noHintSolves;
  final int flawlessSolves;
  final int perfectSolves;

  /// Perfect solves that were also Master tier — the rarest combination.
  final int perfectMasterSolves;

  final Map<DifficultyTier, int> solvesByTier;

  final int distinctDaysPlayed;
  final int currentStreakDays;
  final int longestStreakDays;

  final int earlyBirdSolves;
  final int nightOwlSolves;
  final int midnightSolves;

  final int notePromotions;
  final int totalHintsUsed;

  const PlayerStats({
    this.solves = 0,
    this.solvesByRealm = const {},
    this.completedRealms = const {},
    this.totalStars = 0,
    this.fastestSeconds = 0,
    this.averageSeconds = 0,
    this.totalPlaySeconds = 0,
    this.noHintSolves = 0,
    this.flawlessSolves = 0,
    this.perfectSolves = 0,
    this.perfectMasterSolves = 0,
    this.solvesByTier = const {},
    this.distinctDaysPlayed = 0,
    this.currentStreakDays = 0,
    this.longestStreakDays = 0,
    this.earlyBirdSolves = 0,
    this.nightOwlSolves = 0,
    this.midnightSolves = 0,
    this.notePromotions = 0,
    this.totalHintsUsed = 0,
  });

  int tierSolves(DifficultyTier tier) => solvesByTier[tier] ?? 0;

  /// Expert and Master combined — "the hard stuff".
  int get hardSolves =>
      tierSolves(DifficultyTier.expert) + tierSolves(DifficultyTier.master);

  int realmSolves(String realmName) => solvesByRealm[realmName] ?? 0;

  bool hasCompletedRealm(String realmName) =>
      completedRealms.contains(realmName);

  /// Builds the summary from a raw log.
  ///
  /// [realmSizes] lets the "finish a whole realm" awards work without hardcoding
  /// puzzle counts, which have already changed once when the puzzle set was
  /// regenerated.
  factory PlayerStats.fromLog(
    List<SolveRecord> log, {
    required Map<String, int> realmSizes,
    required int totalPlaySeconds,
    required int totalHintsUsed,
    required int notePromotions,
  }) {
    if (log.isEmpty) {
      return PlayerStats(
        totalPlaySeconds: totalPlaySeconds,
        totalHintsUsed: totalHintsUsed,
        notePromotions: notePromotions,
      );
    }

    // --- group by puzzle so a re-solve does not double-count ---
    final byPuzzle = <String, List<SolveRecord>>{};
    for (final record in log) {
      byPuzzle.putIfAbsent(record.puzzleId, () => []).add(record);
    }

    final solvesByRealm = <String, int>{};
    final solvesByTier = <DifficultyTier, int>{};

    var totalStars = 0;
    var noHint = 0;
    var flawless = 0;
    var perfect = 0;
    var perfectMaster = 0;
    var fastest = 0;
    var bestTimeSum = 0;

    for (final attempts in byPuzzle.values) {
      final first = attempts.first;

      solvesByRealm[first.realmName] =
          (solvesByRealm[first.realmName] ?? 0) + 1;

      final tier = DifficultyTier.fromRating(first.difficulty);
      solvesByTier[tier] = (solvesByTier[tier] ?? 0) + 1;

      totalStars += first.difficulty;

      // "Ever achieved" rather than "most recently achieved".
      if (attempts.any((a) => a.usedNoHints)) noHint++;
      if (attempts.any((a) => a.wasFlawless)) flawless++;
      if (attempts.any((a) => a.wasPerfect)) {
        perfect++;
        if (tier == DifficultyTier.master) perfectMaster++;
      }

      final best = attempts.map((a) => a.seconds).reduce((a, b) => a < b ? a : b);
      bestTimeSum += best;
      if (fastest == 0 || best < fastest) fastest = best;
    }

    // --- day-based stats over every attempt ---
    final days = log.map((r) => r.day).toSet().toList()..sort();

    var earlyBird = 0;
    var nightOwl = 0;
    var midnight = 0;

    for (final record in log) {
      final hour = record.finishedAt.hour;
      if (hour < 9) earlyBird++;
      if (hour >= 22) nightOwl++;
      if (hour >= 1 && hour < 4) midnight++;
    }

    final streaks = _streaks(days);

    return PlayerStats(
      solves: byPuzzle.length,
      solvesByRealm: solvesByRealm,
      completedRealms: {
        for (final entry in solvesByRealm.entries)
          if ((realmSizes[entry.key] ?? 0) > 0 &&
              entry.value >= realmSizes[entry.key]!)
            entry.key,
      },
      totalStars: totalStars,
      fastestSeconds: fastest,
      averageSeconds:
          byPuzzle.isEmpty ? 0 : (bestTimeSum / byPuzzle.length).round(),
      totalPlaySeconds: totalPlaySeconds,
      noHintSolves: noHint,
      flawlessSolves: flawless,
      perfectSolves: perfect,
      perfectMasterSolves: perfectMaster,
      solvesByTier: solvesByTier,
      distinctDaysPlayed: days.length,
      currentStreakDays: streaks.current,
      longestStreakDays: streaks.longest,
      earlyBirdSolves: earlyBird,
      nightOwlSolves: nightOwl,
      midnightSolves: midnight,
      notePromotions: notePromotions,
      totalHintsUsed: totalHintsUsed,
    );
  }

  /// Consecutive-day runs over a sorted list of distinct days.
  ///
  /// The current streak counts only if the most recent day is today or
  /// yesterday — a run that ended last week is history, not a live streak.
  static ({int current, int longest}) _streaks(List<DateTime> sortedDays) {
    if (sortedDays.isEmpty) return (current: 0, longest: 0);

    var longest = 1;
    var run = 1;

    for (var i = 1; i < sortedDays.length; i++) {
      final gap = sortedDays[i].difference(sortedDays[i - 1]).inDays;
      if (gap == 1) {
        run++;
        if (run > longest) longest = run;
      } else if (gap > 1) {
        run = 1;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sinceLast = today.difference(sortedDays.last).inDays;

    return (current: sinceLast <= 1 ? run : 0, longest: longest);
  }
}
