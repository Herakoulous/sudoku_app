import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/game_state.dart';

class SaveService {
  static const String _keyPrefix = 'sudoku_game_';
  static const String _completedPrefix = 'sudoku_completed_';
  static const String _bestTimePrefix = 'sudoku_best_time_';
  static const String _totalTimeKey = 'sudoku_total_time'; // 🔥 NEW
  static const String _hintsUsedKey = 'sudoku_hints_used'; // 🔥 NEW
  static const String _sessionStartKey = 'sudoku_session_start_'; // 🔥 NEW

  // 🔥 NEW: Track total play time across all puzzles
  static Future<void> addPlayTime(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTotal = prefs.getInt(_totalTimeKey) ?? 0;
    await prefs.setInt(_totalTimeKey, currentTotal + seconds);
    print(
        '⏱️ Added $seconds seconds to total play time. Total: ${currentTotal + seconds}s');
  }

  static Future<int> getTotalPlayTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalTimeKey) ?? 0;
  }

  // 🔥 NEW: Track hints used
  static Future<void> incrementHintsUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final currentHints = prefs.getInt(_hintsUsedKey) ?? 0;
    await prefs.setInt(_hintsUsedKey, currentHints + 1);
    print('💡 Hints used: ${currentHints + 1}');
  }

  static Future<int> getTotalHintsUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hintsUsedKey) ?? 0;
  }

  // 🔥 NEW: Session tracking for play time
  static Future<void> startSession(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('$_sessionStartKey$puzzleId', now);
    print('🎮 Started session for $puzzleId at $now');
  }

  static Future<void> endSession(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final startTime = prefs.getInt('$_sessionStartKey$puzzleId');

    if (startTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = ((now - startTime) / 1000).round();

      // Add to total play time
      await addPlayTime(elapsedSeconds);

      // Clear session
      await prefs.remove('$_sessionStartKey$puzzleId');
      print('🎮 Ended session for $puzzleId. Duration: ${elapsedSeconds}s');
    }
  }

  // Save the current game state
  static Future<void> saveGame(GameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${gameState.puzzleId}';

    // 🔥 NEW: Check if puzzle has any user input
    bool hasUserInput = false;
    for (var row in gameState.grid) {
      for (var cell in row) {
        if (cell.hasUserInput) {
          hasUserInput = true;
          break;
        }
      }
      if (hasUserInput) break;
    }

    // 🔥 NEW: Don't save if no user input (except if completed)
    if (!hasUserInput && !gameState.isCompleted) {
      print('⭐️ No user input - skipping save for ${gameState.puzzleId}');
      return;
    }

    // 🔥 Don't save grid if puzzle is completed
    if (gameState.isCompleted) {
      print('✅ Puzzle ${gameState.puzzleId} is completed - clearing save');
      await clearSave(gameState.puzzleId);

      // Still save completion status and best time
      await prefs.setBool('$_completedPrefix${gameState.puzzleId}', true);

      final currentBestTime = await getBestTime(gameState.puzzleId);
      if (currentBestTime == null ||
          gameState.elapsedSeconds < currentBestTime) {
        await prefs.setInt(
            '$_bestTimePrefix${gameState.puzzleId}', gameState.elapsedSeconds);
        print('🏆 New best time: ${gameState.elapsedSeconds}s');
      }

      return;
    }

    // Normal save for incomplete puzzles with user input
    final json = gameState.toJson();
    final jsonString = jsonEncode(json);
    await prefs.setString(key, jsonString);

    print('💾 Game saved: ${gameState.puzzleId} (has input: $hasUserInput)');
  }

  // Load a saved game by puzzleId
  static Future<GameState?> loadGame(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + puzzleId;
    final jsonString = prefs.getString(key);

    if (jsonString == null) {
      print('ℹ️ No saved game found for: $key');
      return null;
    }

    try {
      final json = jsonDecode(jsonString);
      print('✅ Game loaded: $key');
      return GameState.fromJson(json);
    } catch (e) {
      print('❌ Error loading game: $e');
      return null;
    }
  }

  // Check if a puzzle is completed
  static Future<bool> isCompleted(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedPrefix + puzzleId) ?? false;
  }

  // Get best time for a puzzle (in seconds)
  static Future<int?> getBestTime(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestTimePrefix + puzzleId);
  }

  // Get completion stats for a realm
  static Future<Map<String, dynamic>> getRealmStats(
      List<String> puzzleIds) async {
    int completed = 0;
    int total = puzzleIds.length;

    for (String puzzleId in puzzleIds) {
      if (await isCompleted(puzzleId)) {
        completed++;
      }
    }

    return {
      'completed': completed,
      'total': total,
      'percentage': total > 0 ? (completed / total * 100).toInt() : 0,
    };
  }

  // Delete a saved game
  static Future<void> clearSave(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + puzzleId;
    await prefs.remove(key);
    await prefs.remove(key + '_timestamp');
    print('🗑️ Game cleared: $key (completion status preserved)');
  }

  // Get list of all saved game IDs
  static Future<List<String>> getSavedGameIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    return keys
        .where(
            (key) => key.startsWith(_keyPrefix) && !key.endsWith('_timestamp'))
        .map((key) => key.replaceFirst(_keyPrefix, ''))
        .toList();
  }

  // Get when a game was last saved
  static Future<DateTime?> getSaveTimestamp(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + puzzleId + '_timestamp';
    final timestamp = prefs.getInt(key);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  // Get all completed puzzle IDs
  static Future<List<String>> getCompletedPuzzleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    List<String> completedIds = [];

    for (String key in keys) {
      if (key.startsWith(_completedPrefix)) {
        if (prefs.getBool(key) == true) {
          completedIds.add(key.replaceFirst(_completedPrefix, ''));
        }
      }
    }

    return completedIds;
  }

  // 🔥 NEW: Get first completion date (for streak tracking)
  static Future<DateTime?> getFirstCompletionDate() async {
    final completedIds = await getCompletedPuzzleIds();
    if (completedIds.isEmpty) return null;

    // Return today for now (you can enhance this with actual tracking)
    return DateTime.now();
  }
}
