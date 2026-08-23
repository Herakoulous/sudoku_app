import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsService {
  // Settings keys
  static const String _showMistakesKey = 'settings_show_mistakes';
  static const String _showTimerKey = 'settings_show_timer';
  static const String _autoNotesKey = 'settings_auto_notes';
  static const String _soundEffectsKey = 'settings_sound_effects';
  static const String _musicKey = 'settings_music';
  static const String _themeKey = 'settings_theme';

  // Custom color keys
  static const String _customColorsEnabledKey =
      'settings_custom_colors_enabled';
  static const String _gridBackgroundKey = 'settings_grid_background';
  static const String _givenNumbersKey = 'settings_given_numbers';
  static const String _userNumbersKey = 'settings_user_numbers';
  static const String _gridBordersKey = 'settings_grid_borders';
  static const String _selectedCellKey = 'settings_selected_cell';
  static const String _highlightedCellKey = 'settings_highlighted_cell';

  // Default values
  static const bool _defaultShowMistakes = true;
  static const bool _defaultShowTimer = true;
  static const bool _defaultAutoNotes = true;
  static const bool _defaultSoundEffects = false;
  static const bool _defaultMusic = false;
  static const String _defaultTheme = 'dark';
  static const bool _defaultCustomColorsEnabled = true;
  static const Color _defaultGridBackground = Colors.white;
  static const Color _defaultGivenNumbers = Colors.black;
  static const Color _defaultUserNumbers = Color(0xFF1e3a8a);
  static const Color _defaultGridBorders = Colors.black;
  static const Color _defaultSelectedCell = Color(0xFF3b82f6);
  static const Color _defaultHighlightedCell = Color(0xFFdbeafe);

  // ====================
  // SHOW MISTAKES
  // ====================
  static Future<bool> getShowMistakes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showMistakesKey) ?? _defaultShowMistakes;
  }

  static Future<void> setShowMistakes(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showMistakesKey, value);
    print('💾 Show mistakes: $value');
  }

  // ====================
  // SHOW TIMER
  // ====================
  static Future<bool> getShowTimer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTimerKey) ?? _defaultShowTimer;
  }

  static Future<void> setShowTimer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTimerKey, value);
    print('💾 Show timer: $value');
  }

  // ====================
  // AUTO NOTES
  // ====================
  static Future<bool> getAutoNotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoNotesKey) ?? _defaultAutoNotes;
  }

  static Future<void> setAutoNotes(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNotesKey, value);
    print('💾 Auto notes: $value');
  }

  // ====================
  // SOUND EFFECTS
  // ====================
  static Future<bool> getSoundEffects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEffectsKey) ?? _defaultSoundEffects;
  }

  static Future<void> setSoundEffects(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsKey, value);
    print('💾 Sound effects: $value');
  }

  // ====================
  // MUSIC
  // ====================
  static Future<bool> getMusic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_musicKey) ?? _defaultMusic;
  }

  static Future<void> setMusic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicKey, value);
    print('💾 Music: $value');
  }

  // ====================
  // THEME
  // ====================
  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? _defaultTheme;
  }

  static Future<void> setTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value);
    print('💾 Theme: $value');
  }

  // ====================
  // RESOLVE ACTUAL THEME (for auto mode)
  // ====================
  static Future<String> getResolvedTheme(BuildContext context) async {
    final themeSetting = await getTheme();

    if (themeSetting == 'auto') {
      // Get system brightness
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.dark ? 'dark' : 'light';
    }

    return themeSetting;
  }

  // ====================
  // RESTORE DEFAULTS
  // ====================
  static Future<void> restoreDefaults() async {
    await setShowMistakes(_defaultShowMistakes);
    await setShowTimer(_defaultShowTimer);
    await setAutoNotes(_defaultAutoNotes);
    await setSoundEffects(_defaultSoundEffects);
    await setMusic(_defaultMusic);
    await setTheme(_defaultTheme);
    await setCustomColorsEnabled(_defaultCustomColorsEnabled);
    await setGridBackground(_defaultGridBackground);
    await setGivenNumbers(_defaultGivenNumbers);
    await setUserNumbers(_defaultUserNumbers);
    await setGridBorders(_defaultGridBorders);
    await setSelectedCell(_defaultSelectedCell);
    await setHighlightedCell(_defaultHighlightedCell);
    print('🔄 Settings restored to defaults');
  }

  // ====================
  // GET ALL SETTINGS
  // ====================
  static Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'showMistakes': await getShowMistakes(),
      'showTimer': await getShowTimer(),
      'autoNotes': await getAutoNotes(),
      'soundEffects': await getSoundEffects(),
      'music': await getMusic(),
      'theme': await getTheme(),
      'customColorsEnabled': await getCustomColorsEnabled(),
      'gridBackground': await getGridBackground(),
      'givenNumbers': await getGivenNumbers(),
      'userNumbers': await getUserNumbers(),
      'gridBorders': await getGridBorders(),
      'selectedCell': await getSelectedCell(),
      'highlightedCell': await getHighlightedCell(),
    };
  }

  // ====================
  // CUSTOM COLORS ENABLED
  // ====================
  static Future<bool> getCustomColorsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_customColorsEnabledKey) ??
        _defaultCustomColorsEnabled;
  }

  static Future<void> setCustomColorsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customColorsEnabledKey, value);
    print('💾 Custom colors enabled: $value');
  }

  // ====================
  // GRID BACKGROUND COLOR
  // ====================
  static Future<Color> getGridBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_gridBackgroundKey);
    return colorValue != null ? Color(colorValue) : _defaultGridBackground;
  }

  static Future<void> setGridBackground(Color value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gridBackgroundKey, value.value);
    print('💾 Grid background: ${value.value.toRadixString(16)}');
  }

  // ====================
  // GIVEN NUMBERS COLOR
  // ====================
  static Future<Color> getGivenNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_givenNumbersKey);
    return colorValue != null ? Color(colorValue) : _defaultGivenNumbers;
  }

  static Future<void> setGivenNumbers(Color value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_givenNumbersKey, value.value);
    print('💾 Given numbers: ${value.value.toRadixString(16)}');
  }

  // ====================
  // USER NUMBERS COLOR
  // ====================
  static Future<Color> getUserNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_userNumbersKey);
    return colorValue != null ? Color(colorValue) : _defaultUserNumbers;
  }

  static Future<void> setUserNumbers(Color value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userNumbersKey, value.value);
    print('💾 User numbers: ${value.value.toRadixString(16)}');
  }

  // ====================
  // GRID BORDERS COLOR
  // ====================
  static Future<Color> getGridBorders() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_gridBordersKey);
    return colorValue != null ? Color(colorValue) : _defaultGridBorders;
  }

  static Future<void> setGridBorders(Color value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gridBordersKey, value.value);
    print('💾 Grid borders: ${value.value.toRadixString(16)}');
  }

  // ====================
  // SELECTED CELL COLOR
  // ====================
  static Future<Color> getSelectedCell() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_selectedCellKey);
    return colorValue != null ? Color(colorValue) : _defaultSelectedCell;
  }

  static Future<void> setSelectedCell(Color value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedCellKey, value.value);
    print('💾 Selected cell: ${value.value.toRadixString(16)}');
  }

  // ====================
  // HIGHLIGHTED CELL COLOR
  // ====================
  static Future<Color> getHighlightedCell() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_highlightedCellKey);
    return colorValue != null ? Color(colorValue) : _defaultHighlightedCell;
  }

  static Future<void> setHighlightedCell(Color value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highlightedCellKey, value.value);
    print('💾 Highlighted cell: ${value.value.toRadixString(16)}');
  }
}
