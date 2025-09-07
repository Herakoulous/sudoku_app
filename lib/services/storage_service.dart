import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

class StorageService {
  static const String _gameStatePrefix = 'game_state_';

  static Future<bool> saveGameState(GameState gameState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_gameStatePrefix${gameState.puzzleName}';
      final success = await prefs.setString(key, jsonEncode(gameState.toJson()));
      return success;
    } catch (e) {
      print('Error saving game state: $e');
      return false;
    }
  }

  static Future<GameState?> loadGameState(String puzzleName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_gameStatePrefix$puzzleName';
      final jsonString = prefs.getString(key);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return GameState.fromJson(json);
      }
      
      return null;
    } catch (e) {
      print('Error loading game state: $e');
      return null;
    }
  }

  static Future<bool> deleteGameState(String puzzleName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_gameStatePrefix$puzzleName';
      return await prefs.remove(key);
    } catch (e) {
      print('Error deleting game state: $e');
      return false;
    }
  }
}