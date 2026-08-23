import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Puzzles carry a 1–10 difficulty rating. Ten stars is unreadable at a glance,
/// so ratings are bucketed into five named tiers — a player reads a name far
/// faster than they count pips, and the name is what they actually remember.
enum DifficultyTier {
  novice,
  apprentice,
  adept,
  expert,
  master;

  /// Buckets a raw 1–10 rating. Values outside the range are clamped.
  static DifficultyTier fromRating(int rating) {
    final r = rating.clamp(1, 10);
    if (r <= 2) return DifficultyTier.novice;
    if (r <= 4) return DifficultyTier.apprentice;
    if (r <= 6) return DifficultyTier.adept;
    if (r <= 8) return DifficultyTier.expert;
    return DifficultyTier.master;
  }

  String get label {
    switch (this) {
      case DifficultyTier.novice:
        return 'Novice';
      case DifficultyTier.apprentice:
        return 'Apprentice';
      case DifficultyTier.adept:
        return 'Adept';
      case DifficultyTier.expert:
        return 'Expert';
      case DifficultyTier.master:
        return 'Master';
    }
  }

  /// Colour ramp from calm green through gold to alarming red.
  Color get color {
    switch (this) {
      case DifficultyTier.novice:
        return const Color(0xFF5DD39E);
      case DifficultyTier.apprentice:
        return const Color(0xFF56A8E8);
      case DifficultyTier.adept:
        return AppColors.gold;
      case DifficultyTier.expert:
        return const Color(0xFFF08A43);
      case DifficultyTier.master:
        return const Color(0xFFE05A5A);
    }
  }

  /// How many of the five meter segments are lit.
  int get filledSegments => index + 1;
}
