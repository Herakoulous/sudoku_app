import 'package:flutter/material.dart';
import '../data/realm_config.dart';
import '../services/settings_service.dart';
import '../services/realm_color_service.dart';

class RealmTheme {
  final String realmName;
  final Color primaryColor; // Main accent (for UI elements only)
  final Color accentColor; // Lighter accent (for UI elements only)

  // Grid colors - can be customized by user
  final Color backgroundColor;
  final Color textPrimary; // Given numbers
  final Color textSecondary; // User numbers
  final Color borderColor; // Grid borders
  final Color selectedColor; // Selected cells
  final Color highlightedColor; // Highlighted cells
  final Color sameNumberColor; // Same number highlight

  RealmTheme({
    required this.realmName,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.selectedColor,
    required this.highlightedColor,
    required this.sameNumberColor,
  });

  // 🔥 FIXED: Async factory to load custom colors
  static Future<RealmTheme> fromRealm(String realmName) async {
    final primary = await RealmColorService.getPrimaryColor(realmName);
    final accent = await RealmColorService.getAccentColor(realmName);
    // Check if custom colors are enabled
    final customColorsEnabled = await SettingsService.getCustomColorsEnabled();

    if (customColorsEnabled) {
      // Load custom colors from settings (already returns Color objects)
      final gridBg = await SettingsService.getGridBackground();
      final givenNums = await SettingsService.getGivenNumbers();
      final userNums = await SettingsService.getUserNumbers();
      final borders = await SettingsService.getGridBorders();
      final selected = await SettingsService.getSelectedCell();
      final highlighted = await SettingsService.getHighlightedCell();

      return RealmTheme(
        realmName: realmName,
        primaryColor: primary,
        accentColor: accent,
        backgroundColor: gridBg, // ✅ Already a Color
        textPrimary: givenNums, // ✅ Already a Color
        textSecondary: userNums, // ✅ Already a Color
        borderColor: borders, // ✅ Already a Color
        selectedColor: selected, // ✅ Already a Color
        highlightedColor: highlighted, // ✅ Already a Color
        sameNumberColor: Color(0xFFfef3c7), // Keep same number highlight yellow
      );
    } else {
      // Use default high contrast colors
      return RealmTheme(
        realmName: realmName,
        primaryColor: primary,
        accentColor: accent,
        backgroundColor: Colors.white,
        textPrimary: Color(0xFF000000),
        textSecondary: Color(0xFF1e3a8a),
        borderColor: Color(0xFF000000),
        selectedColor: Color(0xFF3b82f6),
        highlightedColor: Color(0xFFdbeafe),
        sameNumberColor: Color(0xFFfef3c7),
      );
    }
  }

  // 🔥 Synchronous factory for backward compatibility (uses defaults)
  factory RealmTheme.fromRealmSync(String realmName) {
    final primary = RealmConfig.getPrimaryColor(realmName); // ✅ Synchronous
    final accent = RealmConfig.getAccentColor(realmName); // ✅ Synchronous

    return RealmTheme(
      realmName: realmName,
      primaryColor: primary,
      accentColor: accent,
      backgroundColor: Colors.white,
      textPrimary: Color(0xFF000000),
      textSecondary: Color(0xFF1e3a8a),
      borderColor: Color(0xFF000000),
      selectedColor: Color(0xFF3b82f6),
      highlightedColor: Color(0xFFdbeafe),
      sameNumberColor: Color(0xFFfef3c7),
    );
  }
}
