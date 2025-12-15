import 'package:flutter/material.dart'; // 🔥 ADD THIS for Color class
import 'puzzles.dart';

class RealmConfig {
  // 🔥 REMOVE 'const' - PuzzleData lists can't be const
  static final Map<String, List<PuzzleData>> realmPuzzles = {
    'Classic Kingdom': Puzzles.getClassicPuzzles(),
    'Kropki Forest': Puzzles.getKropkiPuzzles(),
    'Thermo Desert': Puzzles.getThermoPuzzles(), // 🔥 NEW
    'German Whispers Mountains': Puzzles.getGermanWhispersPuzzles(), // 🔥 NEW
    'XV Sky Islands': Puzzles.getXvPuzzles(), // 🔥 NEW
    'Aqua Labyrinth': Puzzles.getSandwichPuzzles(),
  };

  static const Map<String, String> realmBackgrounds = {
    'Classic Kingdom': 'images/classic_kingdom_background.jpg',
    'Kropki Forest': 'images/kropki_forest_background.jpg',
    'Thermo Desert': 'images/thermo_desert_background.jpg',
    'German Whispers Mountains': 'images/german_whispers_background.jpg',
    'XV Sky Islands': 'images/xv_sky_islands_background.jpg',
    'Aqua Labyrinth': 'images/aqua_labyrinth_background.jpg',
  };

  static const Map<String, Map<String, dynamic>> realmColors = {
    'Classic Kingdom': {
      'primary': 0xFFeca413, // Gold
      'accent': 0xFFfde047,
    },
    'Kropki Forest': {
      'primary': 0xFF22c55e, // Green
      'accent': 0xFF86efac,
    },
    'Thermo Desert': {
      'primary': 0xFFf97316, // Orange
      'accent': 0xFFfbbf24,
    },
    'German Whispers Mountains': {
      'primary': 0xFF06b6d4, // Cyan
      'accent': 0xFF67e8f9,
    },
    'XV Sky Islands': {
      'primary': 0xFF8b5cf6, // Purple
      'accent': 0xFFc4b5fd,
    },
    'Aqua Labyrinth': {
      'primary': 0xFF3b82f6, // Blue
      'accent': 0xFF93c5fd,
    },
  };

  // In realm_config.dart
  static List<PuzzleData> getPuzzlesForRealm(String realmName) {
    print('🔍 Getting puzzles for: $realmName');
    final puzzles = realmPuzzles[realmName] ?? [];
    print('🔍 Found ${puzzles.length} puzzles');
    return puzzles;
  }

  static Color getPrimaryColor(String realmName) {
    final colorValue = realmColors[realmName]?['primary'] ?? 0xFFeca413;
    return Color(colorValue);
  }

  static Color getAccentColor(String realmName) {
    final colorValue = realmColors[realmName]?['accent'] ?? 0xFFfde047;
    return Color(colorValue);
  }

  static String getBackgroundForRealm(String realmName) {
    return realmBackgrounds[realmName] ?? 'images/default_background.jpg';
  }
}
