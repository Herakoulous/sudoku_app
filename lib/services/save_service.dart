import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/game_state.dart';

class SaveService {
  static const String _keyPrefix = 'sudoku_game_';

  // Save the current game state
  static Future<void> saveGame(GameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + gameState.puzzleId;
    final jsonString = jsonEncode(gameState.toJson());
    await prefs.setString(key, jsonString);
    await prefs.setInt(
        key + '_timestamp', DateTime.now().millisecondsSinceEpoch);
    print('✅ Game saved: $key');
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

  // Delete a saved game
  static Future<void> clearSave(String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + puzzleId;
    await prefs.remove(key);
    await prefs.remove(key + '_timestamp');
    print('🗑️ Game cleared: $key');
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
}
