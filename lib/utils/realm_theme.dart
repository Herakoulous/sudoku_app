// import 'package:flutter/material.dart';
// import '../data/realm_config.dart';

// class RealmTheme {
//   final String realmName;
//   final Color primaryColor; // Main accent (gold for Classic)
//   final Color accentColor; // Lighter accent
//   final Color backgroundColor; // Cell backgrounds
//   final Color textPrimary; // Given numbers
//   final Color textSecondary; // User-entered numbers
//   final Color borderColor; // Grid borders
//   final Color selectedColor; // Selected cells
//   final Color highlightedColor; // Highlighted cells
//   final Color sameNumberColor; // Same number highlight

//   RealmTheme({
//     required this.realmName,
//     required this.primaryColor,
//     required this.accentColor,
//     required this.backgroundColor,
//     required this.textPrimary,
//     required this.textSecondary,
//     required this.borderColor,
//     required this.selectedColor,
//     required this.highlightedColor,
//     required this.sameNumberColor,
//   });

//   factory RealmTheme.fromRealm(String realmName) {
//     final primary = RealmConfig.getPrimaryColor(realmName);
//     final accent = RealmConfig.getAccentColor(realmName);

//     // Classic Kingdom: Gold on black
//     // Other realms: Their accent colors on dark backgrounds
//     return RealmTheme(
//       realmName: realmName,
//       primaryColor: primary,
//       accentColor: accent,
//       backgroundColor: Colors.black, // Dark background for all realms
//       textPrimary: primary, // Given numbers in realm color
//       textSecondary: accent.withOpacity(0.7), // User numbers in lighter shade
//       borderColor: primary, // Grid borders in realm color
//       selectedColor: primary.withOpacity(0.3), // Selected cells
//       highlightedColor: primary.withOpacity(0.15), // Highlighted cells
//       sameNumberColor: primary.withOpacity(0.2), // Same number cells
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../data/realm_config.dart';

class RealmTheme {
  final String realmName;
  final Color primaryColor; // Main accent (for UI elements only)
  final Color accentColor; // Lighter accent (for UI elements only)

  // 🔥 GRID COLORS - Always the same for all realms (high contrast)
  final Color backgroundColor; // Pure white
  final Color textPrimary; // Given numbers - pure black
  final Color textSecondary; // User numbers - dark blue
  final Color borderColor; // Grid borders - pure black
  final Color selectedColor; // Selected cells - bright blue
  final Color highlightedColor; // Highlighted cells - light blue
  final Color sameNumberColor; // Same number highlight - light yellow

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

  factory RealmTheme.fromRealm(String realmName) {
    final primary = RealmConfig.getPrimaryColor(realmName);
    final accent = RealmConfig.getAccentColor(realmName);

    // 🔥 GRID USES SAME COLORS FOR ALL REALMS - High Contrast
    return RealmTheme(
      realmName: realmName,
      primaryColor: primary, // Used for UI elements only
      accentColor: accent, // Used for UI elements only

      // 🔥 GRID COLORS - Always consistent for readability
      backgroundColor: Colors.white, // Pure white cells
      textPrimary: Color(0xFF000000), // Given numbers - pure black
      textSecondary: Color(0xFF1e3a8a), // User numbers - dark blue
      borderColor: Color(0xFF000000), // Grid borders - pure black
      selectedColor: Color(0xFF3b82f6), // Selected - bright blue
      highlightedColor: Color(0xFFdbeafe), // Highlighted - light blue
      sameNumberColor: Color(0xFFfef3c7), // Same number - light yellow
    );
  }
}
