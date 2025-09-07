import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

class MenuService {
  static const String _mostRecentPuzzleKey = 'most_recent_puzzle_id';

  static Future<int?> getMostRecentPuzzleId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_mostRecentPuzzleKey);
    } catch (e) {
      print('Error getting most recent puzzle ID: $e');
      return null;
    }
  }

  static Future<GameState?> loadFromStorage(int puzzleId) async {
    // For now, return null - this would be implemented with StorageService
    return null;
  }

  static Future<void> clearSavedState(int puzzleId) async {
    // For now, do nothing - this would be implemented with StorageService
  }
}
