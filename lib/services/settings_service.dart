import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Settings keys
  static const String _showMistakesKey = 'settings_show_mistakes';
  static const String _showTimerKey = 'settings_show_timer';
  static const String _autoNotesKey = 'settings_auto_notes';
  static const String _soundEffectsKey = 'settings_sound_effects';
  static const String _musicKey = 'settings_music';
  static const String _realmBackgroundsKey = 'settings_realm_backgrounds';
  static const String _themeKey = 'settings_theme';

  // Default values
  static const bool _defaultShowMistakes = true;
  static const bool _defaultShowTimer = true;
  static const bool _defaultAutoNotes = false;
  static const bool _defaultSoundEffects = true;
  static const bool _defaultMusic = false;
  static const bool _defaultRealmBackgrounds = true;
  static const String _defaultTheme = 'dark';

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
  // REALM BACKGROUNDS
  // ====================
  static Future<bool> getRealmBackgrounds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_realmBackgroundsKey) ?? _defaultRealmBackgrounds;
  }

  static Future<void> setRealmBackgrounds(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_realmBackgroundsKey, value);
    print('💾 Realm backgrounds: $value');
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
  // RESTORE DEFAULTS
  // ====================
  static Future<void> restoreDefaults() async {
    await setShowMistakes(_defaultShowMistakes);
    await setShowTimer(_defaultShowTimer);
    await setAutoNotes(_defaultAutoNotes);
    await setSoundEffects(_defaultSoundEffects);
    await setMusic(_defaultMusic);
    await setRealmBackgrounds(_defaultRealmBackgrounds);
    await setTheme(_defaultTheme);
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
      'realmBackgrounds': await getRealmBackgrounds(),
      'theme': await getTheme(),
    };
  }
}
