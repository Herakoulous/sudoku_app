import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/models/difficulty_tier.dart';
import 'package:sudoku_realms/models/player_stats.dart';
import 'package:sudoku_realms/models/solve_record.dart';
import 'package:sudoku_realms/services/achievement_service.dart';
import 'package:sudoku_realms/services/progress_service.dart';

SolveRecord _solve({
  String puzzleId = 'classic 1',
  String realm = 'Classic Kingdom',
  int difficulty = 3,
  int seconds = 400,
  int hints = 0,
  int mistakes = 0,
  DateTime? at,
}) {
  return SolveRecord(
    puzzleId: puzzleId,
    realmName: realm,
    difficulty: difficulty,
    seconds: seconds,
    hintsUsed: hints,
    mistakes: mistakes,
    finishedAt: at ?? DateTime(2026, 8, 20, 14, 0),
  );
}

PlayerStats _statsOf(List<SolveRecord> log, {Map<String, int>? sizes}) {
  return PlayerStats.fromLog(
    log,
    realmSizes: sizes ?? const {'Classic Kingdom': 72},
    totalPlaySeconds: 0,
    totalHintsUsed: 0,
    notePromotions: 0,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('catalogue', () {
    test('ids are unique', () {
      final ids = AchievementService.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every award is reachable and has real copy', () {
      for (final a in AchievementService.all) {
        expect(a.target, greaterThan(0), reason: a.id);
        expect(a.name.trim(), isNotEmpty, reason: a.id);
        expect(a.description.trim(), isNotEmpty, reason: a.id);
      }
    });

    test('nothing is unlocked by an empty history', () {
      final statuses = AchievementService.statusesFor(const PlayerStats());
      expect(statuses.where((s) => s.unlocked), isEmpty);
      expect(statuses.length, AchievementService.all.length);
    });

    test('realm targets follow the actual puzzle counts', () {
      // These were hardcoded to 20 before the puzzle set was regenerated, which
      // silently made the realm awards unearnable.
      final classic = AchievementService.byId('realm_classic')!;
      expect(classic.target, greaterThan(20));
    });
  });

  group('stats from the solve log', () {
    test('a re-solve does not count twice', () {
      final stats = _statsOf([
        _solve(puzzleId: 'classic 1'),
        _solve(puzzleId: 'classic 1'),
      ]);
      expect(stats.solves, 1);
    });

    test('purity credits the best attempt, not the latest', () {
      final stats = _statsOf([
        _solve(puzzleId: 'classic 1', hints: 0, mistakes: 0),
        _solve(puzzleId: 'classic 1', hints: 3, mistakes: 4),
      ]);

      expect(stats.perfectSolves, 1,
          reason: 'a later sloppy re-solve must not revoke a perfect run');
      expect(stats.noHintSolves, 1);
      expect(stats.flawlessSolves, 1);
    });

    test('hints and mistakes are tracked separately', () {
      final stats = _statsOf([
        _solve(puzzleId: 'a', hints: 0, mistakes: 2),
        _solve(puzzleId: 'b', hints: 2, mistakes: 0),
      ]);

      expect(stats.noHintSolves, 1);
      expect(stats.flawlessSolves, 1);
      expect(stats.perfectSolves, 0);
    });

    test('fastest time ignores the unsolved case', () {
      expect(_statsOf([]).fastestSeconds, 0);
      expect(_statsOf([_solve(seconds: 95)]).fastestSeconds, 95);
    });

    test('tiers come from the difficulty rating', () {
      final stats = _statsOf([
        _solve(puzzleId: 'a', difficulty: 1),
        _solve(puzzleId: 'b', difficulty: 6),
        _solve(puzzleId: 'c', difficulty: 10),
      ]);

      expect(stats.tierSolves(DifficultyTier.novice), 1);
      expect(stats.tierSolves(DifficultyTier.adept), 1);
      expect(stats.tierSolves(DifficultyTier.master), 1);
      expect(stats.hardSolves, 1);
    });

    test('a realm counts as finished only when every puzzle is done', () {
      final partial = _statsOf(
        [for (var i = 0; i < 3; i++) _solve(puzzleId: 'classic $i')],
        sizes: {'Classic Kingdom': 4},
      );
      expect(partial.completedRealms, isEmpty);

      final full = _statsOf(
        [for (var i = 0; i < 4; i++) _solve(puzzleId: 'classic $i')],
        sizes: {'Classic Kingdom': 4},
      );
      expect(full.completedRealms, {'Classic Kingdom'});
    });

    test('time-of-day awards read the finish hour', () {
      final stats = _statsOf([
        _solve(puzzleId: 'a', at: DateTime(2026, 8, 20, 7, 30)),
        _solve(puzzleId: 'b', at: DateTime(2026, 8, 20, 23, 10)),
        _solve(puzzleId: 'c', at: DateTime(2026, 8, 20, 2, 15)),
      ]);

      expect(stats.earlyBirdSolves, 2, reason: '07:30 and 02:15 are both < 09');
      expect(stats.nightOwlSolves, 1);
      expect(stats.midnightSolves, 1);
    });

    test('streaks need consecutive days', () {
      final stats = _statsOf([
        _solve(puzzleId: 'a', at: DateTime(2026, 8, 1, 12)),
        _solve(puzzleId: 'b', at: DateTime(2026, 8, 2, 12)),
        _solve(puzzleId: 'c', at: DateTime(2026, 8, 3, 12)),
        _solve(puzzleId: 'd', at: DateTime(2026, 8, 9, 12)),
      ]);

      expect(stats.longestStreakDays, 3);
      expect(stats.distinctDaysPlayed, 4);
    });

    test('a stale run is not a live streak', () {
      final stats = _statsOf([
        _solve(puzzleId: 'a', at: DateTime(2020, 1, 1, 12)),
        _solve(puzzleId: 'b', at: DateTime(2020, 1, 2, 12)),
      ]);

      expect(stats.longestStreakDays, 2);
      expect(stats.currentStreakDays, 0);
    });
  });

  group('unlock bookkeeping', () {
    test('an award is reported once and then remembered', () async {
      await ProgressService.recordSolve(_solve());

      final first = await AchievementService.collectNewlyUnlocked();
      expect(first.map((a) => a.id), contains('first_solve'));

      final second = await AchievementService.collectNewlyUnlocked();
      expect(second, isEmpty,
          reason: 'a rebuild must not re-notify the same award');
    });

    test('new awards are reported as progress continues', () async {
      await ProgressService.recordSolve(_solve(puzzleId: 'p0'));
      await AchievementService.collectNewlyUnlocked();

      for (var i = 1; i < 5; i++) {
        await ProgressService.recordSolve(_solve(puzzleId: 'p$i'));
      }

      final next = await AchievementService.collectNewlyUnlocked();
      expect(next.map((a) => a.id), contains('solve_5'));
      expect(next.map((a) => a.id), isNot(contains('first_solve')));
    });

    test('banners are ordered so the biggest award lands last', () async {
      for (var i = 0; i < 10; i++) {
        await ProgressService.recordSolve(
          _solve(puzzleId: 'p$i', difficulty: 10, seconds: 60),
        );
      }

      final earned = await AchievementService.collectNewlyUnlocked();
      expect(earned.length, greaterThan(1));

      for (var i = 1; i < earned.length; i++) {
        expect(
          earned[i].tier.index,
          greaterThanOrEqualTo(earned[i - 1].tier.index),
        );
      }
    });

    test('priming records existing progress silently', () async {
      for (var i = 0; i < 6; i++) {
        await ProgressService.recordSolve(_solve(puzzleId: 'p$i'));
      }

      await AchievementService.primeExistingProgress();

      final earned = await AchievementService.collectNewlyUnlocked();
      expect(earned, isEmpty,
          reason: 'existing players must not be flooded with banners');

      final unlocked = await AchievementService.unlockedIds();
      expect(unlocked, contains('solve_5'));
    });

    test('note promotions accumulate towards their award', () async {
      for (var i = 0; i < 25; i++) {
        await ProgressService.recordNotePromotion();
      }

      final stats = await ProgressService.stats();
      expect(stats.notePromotions, 25);
      expect(
        AchievementService.byId('promote_25')!.isUnlockedBy(stats),
        isTrue,
      );
    });
  });

  group('progress display', () {
    test('partial progress is reported without unlocking', () {
      final stats = _statsOf([
        for (var i = 0; i < 7; i++) _solve(puzzleId: 'p$i'),
      ]);

      final status = AchievementService.statusesFor(stats)
          .firstWhere((s) => s.achievement.id == 'solve_25');

      expect(status.unlocked, isFalse);
      expect(status.progress, 7);
      expect(status.inProgress, isTrue);
      expect(status.fraction, closeTo(7 / 25, 0.001));
    });

    test('progress never overshoots the target', () {
      final stats = _statsOf([
        for (var i = 0; i < 40; i++) _solve(puzzleId: 'p$i'),
      ]);

      final status = AchievementService.statusesFor(stats)
          .firstWhere((s) => s.achievement.id == 'solve_25');

      expect(status.progress, 25);
      expect(status.fraction, 1.0);
    });
  });
}
