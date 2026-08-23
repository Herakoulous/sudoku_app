import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/player_stats.dart';
import '../models/solve_record.dart';
import 'save_service.dart';

/// Owns the solve log — the record of what the player has actually finished.
///
/// The old storage kept only a "completed" boolean and a best time per puzzle,
/// which cannot answer any of the questions achievements ask: was it hint-free,
/// was it flawless, what day was it, was it a Master board. Each finish now
/// appends a record, and every statistic is derived from that one source.
class ProgressService {
  ProgressService._();

  static const String _logKey = 'solve_log';
  static const String _promotionsKey = 'note_promotions';

  /// Keeps storage bounded. A very long log costs read time on every finish,
  /// and the oldest entries only matter for totals that are already reflected in
  /// the awards the player has permanently unlocked.
  static const int _maxRecords = 2000;

  // ---------------------------------------------------------------------------
  // SOLVE LOG
  // ---------------------------------------------------------------------------

  static Future<List<SolveRecord>> log() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => SolveRecord.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // A corrupt log must not make the game unplayable; losing achievement
      // history is bad, being unable to finish a puzzle is worse.
      return const [];
    }
  }

  static Future<void> recordSolve(SolveRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await log();

    final updated = [...existing, record];
    if (updated.length > _maxRecords) {
      updated.removeRange(0, updated.length - _maxRecords);
    }

    await prefs.setString(
      _logKey,
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }

  /// Counts a note confirmed by double tap, for the matching award.
  static Future<void> recordNotePromotion() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_promotionsKey) ?? 0;
    await prefs.setInt(_promotionsKey, current + 1);
  }

  static Future<int> notePromotions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_promotionsKey) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // DERIVED STATS
  // ---------------------------------------------------------------------------

  static Future<PlayerStats> stats() async {
    final records = await log();

    return PlayerStats.fromLog(
      records,
      realmSizes: {
        for (final realm in RealmConfig.realms)
          realm.name: RealmConfig.getPuzzlesForRealm(realm.name).length,
      },
      totalPlaySeconds: await SaveService.getTotalPlayTime(),
      totalHintsUsed: await SaveService.getTotalHintsUsed(),
      notePromotions: await notePromotions(),
    );
  }

  /// Rebuilds a minimal log from the old per-puzzle completion flags.
  ///
  /// Players upgrading from a build without the log would otherwise appear to
  /// have finished nothing. Their history is thin — the old data cannot say
  /// whether a solve used hints, and there is no honest way to invent that — so
  /// migrated records are marked as having used a hint and made a mistake, which
  /// keeps them out of the purity awards rather than handing them out unearned.
  static Future<void> migrateFromCompletionFlags() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_logKey)) return;

    final completedIds = await SaveService.getCompletedPuzzleIds();
    if (completedIds.isEmpty) {
      await prefs.setString(_logKey, '[]');
      return;
    }

    final now = DateTime.now();
    final records = <SolveRecord>[];

    for (final id in completedIds) {
      final realmName = RealmConfig.realmForPuzzleId(id);
      final puzzle = Puzzles.getPuzzle(id);

      // Completion flags outlive the puzzles they refer to — the variant sets
      // were regenerated, so old ids may no longer exist. Skip those rather
      // than failing the whole migration.
      if (realmName == null || puzzle == null) continue;

      records.add(
        SolveRecord(
          puzzleId: id,
          realmName: realmName,
          difficulty: puzzle.difficulty,
          seconds: await SaveService.getBestTime(id) ?? 0,
          hintsUsed: 1,
          mistakes: 1,
          finishedAt: now,
        ),
      );
    }

    await prefs.setString(
      _logKey,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
    await prefs.remove(_promotionsKey);
  }
}
