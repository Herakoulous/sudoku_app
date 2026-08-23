import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/data/puzzles.dart';
import 'package:sudoku_realms/models/variant_constraint.dart';
import 'package:sudoku_realms/services/daily_service.dart';

Future<void> _prime(WidgetTester tester) =>
    tester.runAsync(() => DailyService.weekOf(DateTime(2026, 8, 24)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('pool', () {
    testWidgets('loads attributed, solution-backed puzzles', (tester) async {
      await _prime(tester);

      final week = await tester.runAsync(
        () => DailyService.weekOf(DateTime(2026, 8, 24)),
      );

      expect(week, isNotNull);
      expect(week!.length, greaterThanOrEqualTo(7));

      for (final daily in week) {
        expect(daily.author.trim(), isNotEmpty,
            reason: 'a daily puzzle must credit its author');
        expect(daily.puzzle.solution, isNotNull);
        // Registered so the game pipeline can find it.
        expect(Puzzles.getPuzzle(daily.id), isNotNull);
      }
    });

    testWidgets('kropki dailies carry their dots and a valid solution',
        (tester) async {
      await _prime(tester);
      final week = await tester.runAsync(
        () => DailyService.weekOf(DateTime(2026, 8, 24)),
      );

      final kropki = week!.where((d) => d.type == 'kropki').toList();
      if (kropki.isEmpty) return;

      for (final daily in kropki) {
        final dots = daily.puzzle.constraints.where((c) =>
            c.type == ConstraintType.KROPKI_WHITE ||
            c.type == ConstraintType.KROPKI_BLACK);
        expect(dots, isNotEmpty, reason: '${daily.id} has no dots');

        // Every dot must be consistent with the stated solution.
        final s = daily.puzzle.solution!;
        for (final dot in dots) {
          final a = s[dot.row1][dot.col1];
          final b = s[dot.row2][dot.col2];
          if (dot.type == ConstraintType.KROPKI_WHITE) {
            expect((a - b).abs(), 1, reason: '${daily.id} white dot $a/$b');
          } else {
            expect(a == 2 * b || b == 2 * a, isTrue,
                reason: '${daily.id} black dot $a/$b');
          }
        }
      }
    });
  });

  group('scheduling', () {
    testWidgets('today is deterministic for a given date', (tester) async {
      await _prime(tester);

      final a = await tester.runAsync(
        () => DailyService.today(DateTime(2026, 8, 26, 9)),
      );
      final b = await tester.runAsync(
        () => DailyService.today(DateTime(2026, 8, 26, 21)),
      );

      expect(a!.id, b!.id, reason: 'same day → same puzzle');
    });

    testWidgets('the week ramps from easiest Monday to hardest Sunday',
        (tester) async {
      await _prime(tester);
      final week = await tester.runAsync(
        () => DailyService.weekOf(DateTime(2026, 8, 24)),
      );

      final diffs = week!.map((d) => d.difficulty).toList();
      for (var i = 1; i < diffs.length; i++) {
        expect(diffs[i], greaterThanOrEqualTo(diffs[i - 1]),
            reason: 'difficulty should not drop across the week');
      }

      // Monday's puzzle is the week's easiest.
      final monday = await tester.runAsync(
        () => DailyService.today(DateTime(2026, 8, 24)), // a Monday
      );
      expect(monday!.difficulty, diffs.first);
    });

    testWidgets('a week serves varied rules, never a plain classic grid',
        (tester) async {
      await _prime(tester);
      final week = await tester.runAsync(
        () => DailyService.weekOf(DateTime(2026, 8, 24)),
      );

      final types = week!.map((d) => d.type).toSet();
      expect(types.contains('classic'), isFalse,
          reason: 'the daily is meant to bring a new rule each day');
      expect(types.length, greaterThanOrEqualTo(3),
          reason: 'a week should mix several rule types');

      // Every daily carries variant constraints (it is not a bare grid).
      for (final daily in week) {
        expect(daily.puzzle.constraints, isNotEmpty,
            reason: '${daily.id} should carry its variant markings');
      }
    });

    testWidgets('past days of the week are individually playable',
        (tester) async {
      await _prime(tester);

      // Monday..Sunday of a known week.
      final dates = DailyService.weekDates(DateTime(2026, 8, 26)); // a Wednesday
      expect(dates.length, 7);
      expect(dates.first.weekday, DateTime.monday);
      expect(dates.last.weekday, DateTime.sunday);

      // Each date resolves to a concrete puzzle, matching that day's slot.
      for (final date in dates) {
        final byDate = await tester.runAsync(
          () => DailyService.puzzleFor(date),
        );
        final byToday = await tester.runAsync(
          () => DailyService.today(date),
        );
        expect(byDate, isNotNull);
        expect(byDate!.id, byToday!.id,
            reason: 'puzzleFor(date) and today(date) agree');
      }
    });

    testWidgets('different weeks can draw a different set', (tester) async {
      await _prime(tester);

      final w1 = await tester.runAsync(
        () => DailyService.weekOf(DateTime(2026, 8, 24)),
      );
      final w2 = await tester.runAsync(
        () => DailyService.weekOf(DateTime(2026, 9, 21)),
      );

      // Not asserting total disjointness (the pool wraps), just that the slice
      // moved — the first ids should differ across a month.
      expect(w1!.map((d) => d.id).toSet(),
          isNot(equals(w2!.map((d) => d.id).toSet())));
    });
  });

  group('streak', () {
    testWidgets('builds across consecutive solved days', (tester) async {
      final base = DateTime(2026, 8, 24);

      await DailyService.markSolved(base);
      await DailyService.markSolved(base.add(const Duration(days: 1)));
      await DailyService.markSolved(base.add(const Duration(days: 2)));

      final streak = await DailyService.streak(
        base.add(const Duration(days: 2)),
      );
      expect(streak, 3);
    });

    testWidgets('a missed day breaks the streak', (tester) async {
      final base = DateTime(2026, 8, 24);

      await DailyService.markSolved(base);
      // skip day +1
      await DailyService.markSolved(base.add(const Duration(days: 2)));

      final streak = await DailyService.streak(
        base.add(const Duration(days: 2)),
      );
      expect(streak, 1, reason: 'only today counts after a gap');
    });

    testWidgets('yesterday-only still counts as a live streak', (tester) async {
      final today = DateTime(2026, 8, 24);
      await DailyService.markSolved(today.subtract(const Duration(days: 1)));

      // Today not solved yet, but yesterday keeps the run alive.
      expect(await DailyService.streak(today), 1);
    });

    testWidgets('no solves means no streak', (tester) async {
      expect(await DailyService.streak(DateTime(2026, 8, 24)), 0);
    });
  });
}
