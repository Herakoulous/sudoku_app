import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// =============================================================================
/// SUDOKU REALMS — DESIGN SYSTEM
/// =============================================================================
/// Single source of truth for colour, spacing, radius, motion and type.
///
/// Direction: modern layout and typography carrying one fantasy thread — warm
/// gold on deep cool ink. Realm artwork supplies the atmosphere; the UI chrome
/// stays quiet so the art and the puzzle do the talking.
/// =============================================================================

// -----------------------------------------------------------------------------
// COLOUR
// -----------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // --- Base surfaces: cool deep ink, layered by elevation ---
  static const Color ink = Color(0xFF080B11);
  static const Color surface = Color(0xFF10151F);
  static const Color surfaceRaised = Color(0xFF19202D);
  static const Color surfaceHigh = Color(0xFF222B3C);

  // --- Strokes ---
  static const Color stroke = Color(0xFF2B3446);
  static const Color strokeSoft = Color(0xFF1D2534);

  // --- Gold: the fantasy accent, used sparingly and with intent ---
  static const Color gold = Color(0xFFE0A93B);
  static const Color goldBright = Color(0xFFF6D488);
  static const Color goldDeep = Color(0xFFA9751F);

  // --- Text hierarchy ---
  static const Color textPrimary = Color(0xFFF3F1EC);
  static const Color textSecondary = Color(0xFF9AA4B6);
  static const Color textMuted = Color(0xFF5E6878);
  static const Color textOnGold = Color(0xFF17120A);

  // --- Semantic ---
  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);

  // --- Scrim for layering UI over artwork ---
  static const Color scrim = Color(0xFF080B11);

  /// Vertical scrim that keeps text legible over realm art.
  static LinearGradient artScrim({
    double topOpacity = 0.10,
    double bottomOpacity = 0.92,
  }) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        scrim.withValues(alpha: topOpacity),
        scrim.withValues(alpha: (topOpacity + bottomOpacity) / 2.4),
        scrim.withValues(alpha: bottomOpacity),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }

  /// The app's ambient background — a subtle vertical wash, never flat black.
  static const LinearGradient backgroundWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141B27), Color(0xFF0A0E16), Color(0xFF080B11)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gold fill used on primary actions.
  static const LinearGradient goldFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0C767), Color(0xFFE0A93B), Color(0xFFC98F26)],
    stops: [0.0, 0.55, 1.0],
  );
}

// -----------------------------------------------------------------------------
// SPACING — 4pt base scale
// -----------------------------------------------------------------------------

class AppSpace {
  AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Standard horizontal page gutter.
  static const double gutter = 20;
}

// -----------------------------------------------------------------------------
// RADIUS
// -----------------------------------------------------------------------------

class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

// -----------------------------------------------------------------------------
// MOTION — one place to keep timing consistent
// -----------------------------------------------------------------------------

class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve standard = Curves.easeInOutCubic;

  /// Delay for the nth item in a staggered entrance.
  static Duration stagger(int index, {int stepMs = 55, int maxMs = 440}) {
    final ms = index * stepMs;
    return Duration(milliseconds: ms > maxMs ? maxMs : ms);
  }
}

// -----------------------------------------------------------------------------
// SHADOW
// -----------------------------------------------------------------------------

class AppShadow {
  AppShadow._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.45),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get lifted => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.60),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.40,
    double blur = 24,
    double spread = 0,
  }) =>
      [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];
}

// -----------------------------------------------------------------------------
// TYPE
// -----------------------------------------------------------------------------

class AppType {
  AppType._();

  static const String display = 'CinzelDecorative';

  /// Hero wordmark. Cinzel is reserved for the app name and realm names only —
  /// everywhere else uses the platform UI face so body copy stays readable.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.04,
    letterSpacing: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: display,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: 1.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: display,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.6,
    color: AppColors.textPrimary,
  );

  // --- UI type: platform default, modern and neutral ---

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
  );

  /// Small all-caps eyebrow text. Pair with `.toUpperCase()`.
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  /// Tabular figures for timers and counters so digits do not jitter.
  static const TextStyle numeric = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.4,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

// -----------------------------------------------------------------------------
// MATERIAL THEME
// -----------------------------------------------------------------------------

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.textOnGold,
        secondary: AppColors.goldBright,
        onSecondary: AppColors.textOnGold,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      splashFactory: InkRipple.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionColor: Color(0x33E0A93B),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.strokeSoft,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
    );
  }
}
