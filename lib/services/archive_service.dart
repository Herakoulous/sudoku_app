import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/archived_game.dart';
import '../models/game_state.dart';

/// Keeps a browsable archive of played games.
///
/// One entry per puzzle — the latest state, whether it was left half-finished or
/// carried to a solve. Each entry holds the entire game state, action history
/// included, so a game can be resumed exactly or replayed move by move.
///
/// This is heavier than a bare "completed" flag, which is why it is capped: a
/// full state with a long undo stack runs to tens of kilobytes, and an unbounded
/// archive would eventually bloat the preferences store it lives in.
class ArchiveService {
  ArchiveService._();

  static const String _indexKey = 'archive_index';
  static const String _entryPrefix = 'archive_game_';

  /// How many games to keep. When full, the oldest *completed* game is dropped
  /// first, so an in-progress game is never evicted out from under the player.
  static const int _limit = 60;

  // ---------------------------------------------------------------------------
  // WRITING
  // ---------------------------------------------------------------------------

  /// Records the current state of a game.
  ///
  /// Called whenever a game is saved or finished. A puzzle with no user input at
  /// all is skipped, so merely opening a puzzle does not clutter the archive.
  static Future<void> record(GameState state) async {
    final filled = _countFilled(state);
    if (filled == 0 && !state.isCompleted) return;

    final prefs = await SharedPreferences.getInstance();

    final entry = ArchivedGame(
      puzzleId: state.puzzleId,
      realmName: RealmConfig.realmForPuzzleId(state.puzzleId) ?? '',
      completed: state.isCompleted,
      savedAt: DateTime.now(),
      elapsedSeconds: state.elapsedSeconds,
      mistakes: _countMistakes(state),
      filled: filled,
      state: state,
    );

    await prefs.setString(
      '$_entryPrefix${state.puzzleId}',
      jsonEncode(entry.toJson()),
    );

    final index = _readIndex(prefs)..remove(state.puzzleId);
    index.insert(0, state.puzzleId); // most recent first
    await _writeIndex(prefs, index);

    await _enforceLimit(prefs);
  }

  // ---------------------------------------------------------------------------
  // READING
  // ---------------------------------------------------------------------------

  /// Every archived game, newest first.
  static Future<List<ArchivedGame>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <ArchivedGame>[];

    for (final id in _readIndex(prefs)) {
      final game = _readEntry(prefs, id);
      if (game != null) out.add(game);
    }

    return out;
  }

  static Future<ArchivedGame?> load(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    return _readEntry(prefs, puzzleId);
  }

  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return _readIndex(prefs).length;
  }

  // ---------------------------------------------------------------------------
  // DELETING
  // ---------------------------------------------------------------------------

  static Future<void> delete(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_entryPrefix$puzzleId');
    await _writeIndex(prefs, _readIndex(prefs)..remove(puzzleId));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in _readIndex(prefs)) {
      await prefs.remove('$_entryPrefix$id');
    }
    await prefs.remove(_indexKey);
  }

  // ---------------------------------------------------------------------------
  // INTERNALS
  // ---------------------------------------------------------------------------

  static List<String> _readIndex(SharedPreferences prefs) =>
      prefs.getStringList(_indexKey)?.toList() ?? <String>[];

  static Future<void> _writeIndex(
    SharedPreferences prefs,
    List<String> index,
  ) =>
      prefs.setStringList(_indexKey, index);

  static ArchivedGame? _readEntry(SharedPreferences prefs, String puzzleId) {
    final raw = prefs.getString('$_entryPrefix$puzzleId');
    if (raw == null) return null;

    try {
      return ArchivedGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Could not decode archived game $puzzleId: $e');
      return null;
    }
  }

  /// Trims the archive to [_limit], removing the oldest completed games first
  /// and only falling back to the oldest of anything if every game is finished.
  static Future<void> _enforceLimit(SharedPreferences prefs) async {
    final index = _readIndex(prefs);
    if (index.length <= _limit) return;

    // index is newest-first; the tail is the oldest.
    final removable = <String>[];
    for (final id in index.reversed) {
      final game = _readEntry(prefs, id);
      if (game != null && game.completed) removable.add(id);
      if (index.length - removable.length <= _limit) break;
    }

    // Still over the cap (all remaining are in-progress) — drop the very oldest.
    var trimmed = index.where((id) => !removable.contains(id)).toList();
    while (trimmed.length > _limit) {
      removable.add(trimmed.removeLast());
    }

    for (final id in removable) {
      await prefs.remove('$_entryPrefix$id');
    }
    await _writeIndex(prefs, trimmed);
  }

  static int _countFilled(GameState state) {
    var filled = 0;
    for (final row in state.grid) {
      for (final cell in row) {
        if (!cell.isGiven && cell.number != null) filled++;
      }
    }
    return filled;
  }

  static int _countMistakes(GameState state) {
    final solution = Puzzles.getPuzzle(state.puzzleId)?.solution;
    if (solution == null) return 0;

    var mistakes = 0;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final cell = state.grid[r][c];
        if (!cell.isGiven &&
            cell.number != null &&
            cell.number != solution[r][c]) {
          mistakes++;
        }
      }
    }
    return mistakes;
  }
}
