import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/models/dungeon.dart';
import 'package:sudoku_realms/services/dungeon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('rank bands', () {
    test('a fresh rating lands in an early rank', () {
      const fresh = DungeonRating();
      expect(fresh.rating, 1000);
      expect(fresh.rank, DungeonRank.silver);
    });

    test('ranks climb with rating', () {
      expect(DungeonRank.forRating(0), DungeonRank.bronze);
      expect(DungeonRank.forRating(950), DungeonRank.silver);
      expect(DungeonRank.forRating(1200), DungeonRank.gold);
      expect(DungeonRank.forRating(2000), DungeonRank.master);
    });

    test('progress within a rank runs 0 to 1', () {
      final silver = DungeonRank.silver;
      expect(silver.progressAt(silver.floor), 0);
      expect(silver.progressAt(silver.next!.floor), 1);
      expect(silver.progressAt(silver.floor - 100), 0,
          reason: 'clamped below the floor');
    });

    test('the top rank is always full', () {
      expect(DungeonRank.master.next, isNull);
      expect(DungeonRank.master.progressAt(9999), 1);
    });
  });

  group('elo maths', () {
    test('winning gains rating, losing loses it', () {
      const current = 1000;
      final win = DungeonService.projectedRating(
          current: current, difficulty: 5, won: true);
      final loss = DungeonService.projectedRating(
          current: current, difficulty: 5, won: false);

      expect(win, greaterThan(current));
      expect(loss, lessThan(current));
    });

    test('beating a harder puzzle is worth more', () {
      const current = 1000;
      final easyWin = DungeonService.projectedRating(
          current: current, difficulty: 1, won: true);
      final hardWin = DungeonService.projectedRating(
          current: current, difficulty: 10, won: true);

      expect(hardWin - current, greaterThan(easyWin - current));
    });

    test('losing to an easy puzzle costs more', () {
      const current = 1000;
      final easyLoss = DungeonService.projectedRating(
          current: current, difficulty: 1, won: false);
      final hardLoss = DungeonService.projectedRating(
          current: current, difficulty: 10, won: false);

      // Dropping an easy one is the bigger upset, so it stings more.
      expect(current - easyLoss, greaterThan(current - hardLoss));
    });

    test('rating never falls below the floor', () {
      var rating = 100;
      for (var i = 0; i < 50; i++) {
        rating = DungeonService.projectedRating(
            current: rating, difficulty: 1, won: false);
      }
      expect(rating, greaterThanOrEqualTo(100));
    });

    test('the puzzle scale is monotonic in difficulty', () {
      var previous = 0;
      for (var d = 1; d <= 10; d++) {
        final r = DungeonService.puzzleRating(d);
        expect(r, greaterThan(previous));
        previous = r;
      }
    });
  });

  group('provisional ratings', () {
    test('a new player swings harder than an established one', () {
      const current = 1000;

      final newWin = DungeonService.projectedRating(
          current: current, difficulty: 5, won: true, played: 0);
      final veteranWin = DungeonService.projectedRating(
          current: current, difficulty: 5, won: true, played: 100);

      expect(newWin - current, greaterThan(veteranWin - current),
          reason: 'a newcomer should climb faster toward their true level');

      final newLoss = DungeonService.projectedRating(
          current: current, difficulty: 5, won: false, played: 0);
      final veteranLoss = DungeonService.projectedRating(
          current: current, difficulty: 5, won: false, played: 100);

      expect(current - newLoss, greaterThan(current - veteranLoss),
          reason: 'and drop faster too');
    });

    test('the swing shrinks as games accumulate', () {
      const current = 1000;
      int gain(int played) =>
          DungeonService.projectedRating(
              current: current, difficulty: 5, won: true, played: played) -
          current;

      // Non-increasing across the provisional window and beyond.
      var previous = gain(0);
      for (final played in const [3, 6, 9, 12, 15, 30]) {
        final g = gain(played);
        expect(g, lessThanOrEqualTo(previous));
        previous = g;
      }
    });

    test('isProvisional flips once the window is cleared', () {
      expect(DungeonService.isProvisional(const DungeonRating(played: 0)),
          isTrue);
      expect(DungeonService.isProvisional(const DungeonRating(played: 14)),
          isTrue);
      expect(DungeonService.isProvisional(const DungeonRating(played: 15)),
          isFalse);
    });
  });

  group('recording outcomes', () {
    test('a win updates rating, played, won and streak', () async {
      final result = await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: true,
        difficulty: 5,
        elapsed: const Duration(minutes: 4),
        mistakes: 1,
      );

      expect(result.won, isTrue);
      expect(result.delta, greaterThan(0));

      final rating = await DungeonService.ratingFor(DungeonMode.survival);
      expect(rating.played, 1);
      expect(rating.won, 1);
      expect(rating.streak, 1);
      expect(rating.rating, result.ratingAfter);
    });

    test('a loss resets the streak', () async {
      for (var i = 0; i < 3; i++) {
        await DungeonService.recordOutcome(
          mode: DungeonMode.survival,
          won: true,
          difficulty: 5,
          elapsed: Duration.zero,
          mistakes: 0,
        );
      }
      var rating = await DungeonService.ratingFor(DungeonMode.survival);
      expect(rating.streak, 3);

      await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: false,
        difficulty: 5,
        elapsed: Duration.zero,
        mistakes: 3,
      );
      rating = await DungeonService.ratingFor(DungeonMode.survival);
      expect(rating.streak, 0);
      expect(rating.played, 4);
      expect(rating.won, 3);
    });

    test('the two modes rate independently', () async {
      await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: true,
        difficulty: 8,
        elapsed: Duration.zero,
        mistakes: 0,
      );

      final survival = await DungeonService.ratingFor(DungeonMode.survival);
      final rush = await DungeonService.ratingFor(DungeonMode.timeRush);

      expect(survival.played, 1);
      expect(rush.played, 0, reason: 'Time Rush is untouched by a Survival run');
    });
  });

  group('matchmaking', () {
    test('always returns a solution-backed classic puzzle', () async {
      final puzzle = await DungeonService.matchPuzzle(
        DungeonMode.survival,
        random: Random(1),
      );
      expect(puzzle, isNotNull);
      expect(puzzle!.solution, isNotNull);
      expect(puzzle.id, startsWith('classic'));
    });

    test('a stronger player is matched to harder puzzles on average',
        () async {
      // Seed a high rating, then compare the difficulty of matched puzzles to a
      // fresh account's.
      for (var i = 0; i < 12; i++) {
        await DungeonService.recordOutcome(
          mode: DungeonMode.timeRush,
          won: true,
          difficulty: 10,
          elapsed: Duration.zero,
          mistakes: 0,
        );
      }

      var strongTotal = 0;
      final rng = Random(7);
      for (var i = 0; i < 20; i++) {
        strongTotal +=
            (await DungeonService.matchPuzzle(DungeonMode.timeRush, random: rng))!
                .difficulty;
      }

      await DungeonService.reset();

      var freshTotal = 0;
      for (var i = 0; i < 20; i++) {
        freshTotal +=
            (await DungeonService.matchPuzzle(DungeonMode.timeRush, random: rng))!
                .difficulty;
      }

      expect(strongTotal, greaterThan(freshTotal));
    });
  });

  group('mode rules', () {
    test('survival highlights mistakes and caps them', () {
      expect(DungeonMode.survival.highlightsMistakes, isTrue);
      expect(DungeonMode.survival.mistakeLimit, 3);
      expect(DungeonMode.survival.timeLimit, isNull);
    });

    test('time rush hides mistakes and is timed', () {
      expect(DungeonMode.timeRush.highlightsMistakes, isFalse);
      expect(DungeonMode.timeRush.timeLimit, const Duration(minutes: 30));
    });
  });

  group('rating history', () {
    test('starts as a single seed point', () async {
      final history = await DungeonService.history(DungeonMode.survival);
      expect(history, [const DungeonRating().rating]);
    });

    test('grows by one point per recorded game, seed included', () async {
      for (var i = 0; i < 3; i++) {
        await DungeonService.recordOutcome(
          mode: DungeonMode.survival,
          won: true,
          difficulty: 5,
          elapsed: Duration.zero,
          mistakes: 0,
        );
      }

      final history = await DungeonService.history(DungeonMode.survival);
      // Seed plus three games.
      expect(history.length, 4);
      expect(history.first, const DungeonRating().rating);
      expect(history.last, greaterThan(history.first),
          reason: 'three wins should trend upward');
    });

    test('the two modes keep separate histories', () async {
      await DungeonService.recordOutcome(
        mode: DungeonMode.timeRush,
        won: true,
        difficulty: 6,
        elapsed: Duration.zero,
        mistakes: 0,
      );

      expect((await DungeonService.history(DungeonMode.timeRush)).length, 2);
      expect((await DungeonService.history(DungeonMode.survival)).length, 1);
    });

    test('reset clears history back to the seed', () async {
      await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: true,
        difficulty: 5,
        elapsed: Duration.zero,
        mistakes: 0,
      );
      await DungeonService.reset();

      expect((await DungeonService.history(DungeonMode.survival)).length, 1);
    });
  });

  group('chosen difficulty', () {
    test('honours an explicit difficulty over the rating match', () async {
      // A fresh account would normally be matched low; asking for level 9 must
      // override that.
      final puzzle = await DungeonService.matchPuzzle(
        DungeonMode.survival,
        difficulty: 9,
        random: Random(3),
      );
      expect(puzzle, isNotNull);
      expect((puzzle!.difficulty - 9).abs(), lessThanOrEqualTo(2),
          reason: 'should land near the requested level');
    });

    test('suggested difficulty rises with rating', () async {
      final low = await DungeonService.suggestedDifficulty(DungeonMode.survival);

      for (var i = 0; i < 15; i++) {
        await DungeonService.recordOutcome(
          mode: DungeonMode.survival,
          won: true,
          difficulty: 10,
          elapsed: Duration.zero,
          mistakes: 0,
        );
      }

      final high =
          await DungeonService.suggestedDifficulty(DungeonMode.survival);
      expect(high, greaterThan(low));
    });
  });

  group('game log', () {
    test('records attempts newest-first with a puzzle id', () async {
      await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: false,
        difficulty: 4,
        elapsed: const Duration(minutes: 2),
        mistakes: 3,
        puzzleId: 'puzzle-a',
      );
      await DungeonService.recordOutcome(
        mode: DungeonMode.timeRush,
        won: true,
        difficulty: 7,
        elapsed: const Duration(minutes: 5),
        mistakes: 0,
        puzzleId: 'puzzle-b',
      );

      final log = await DungeonService.gameLog();
      expect(log.length, 2);
      expect(log.first.puzzleId, 'puzzle-b', reason: 'newest first');
      expect(log.first.mode, DungeonMode.timeRush);
      expect(log.first.won, isTrue);
      expect(log.first.difficulty, 7);
      expect(log[1].puzzleId, 'puzzle-a');
      expect(log[1].elapsed, const Duration(minutes: 2));
    });

    test('an attempt without a puzzle id is not logged', () async {
      await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: true,
        difficulty: 5,
        elapsed: Duration.zero,
        mistakes: 0,
      );
      expect(await DungeonService.gameLog(), isEmpty);
    });

    test('reset clears the log', () async {
      await DungeonService.recordOutcome(
        mode: DungeonMode.survival,
        won: true,
        difficulty: 5,
        elapsed: Duration.zero,
        mistakes: 0,
        puzzleId: 'puzzle-a',
      );
      await DungeonService.reset();
      expect(await DungeonService.gameLog(), isEmpty);
    });
  });
}
