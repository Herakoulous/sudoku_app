import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The two ways to play ranked.
enum DungeonMode {
  /// Unlimited time; three mistakes ends the run. Mistakes are shown as you make
  /// them, so it rewards care over speed.
  survival,

  /// Thirty minutes; mistakes are hidden until the end, so a wrong digit can
  /// quietly cost you the puzzle. Rewards nerve and pace.
  timeRush;

  String get title {
    switch (this) {
      case DungeonMode.survival:
        return 'Survival';
      case DungeonMode.timeRush:
        return 'Time Rush';
    }
  }

  String get tagline {
    switch (this) {
      case DungeonMode.survival:
        return 'Three mistakes and you are out';
      case DungeonMode.timeRush:
        return 'Thirty minutes, mistakes hidden';
    }
  }

  IconData get icon {
    switch (this) {
      case DungeonMode.survival:
        return Icons.favorite_rounded;
      case DungeonMode.timeRush:
        return Icons.bolt_rounded;
    }
  }

  /// Mistakes allowed before the run ends. Time Rush has no limit — a wrong
  /// digit just sits there, costing you time you do not know you are losing.
  int get mistakeLimit {
    switch (this) {
      case DungeonMode.survival:
        return 3;
      case DungeonMode.timeRush:
        return 1 << 30; // effectively unlimited
    }
  }

  /// Whether wrong digits are highlighted as they are entered.
  bool get highlightsMistakes => this == DungeonMode.survival;

  /// The time limit, or null for untimed.
  Duration? get timeLimit {
    switch (this) {
      case DungeonMode.survival:
        return null;
      case DungeonMode.timeRush:
        return const Duration(minutes: 30);
    }
  }

  /// Key used to store this mode's rating.
  String get storageKey => name;
}

/// A named rating band, so a number becomes a rank a player can feel.
enum DungeonRank {
  bronze('Bronze', 0, Color(0xFFC08552)),
  silver('Silver', 900, Color(0xFFB6C2D1)),
  gold('Gold', 1100, AppColors.gold),
  platinum('Platinum', 1350, Color(0xFF5FD3C8)),
  diamond('Diamond', 1600, Color(0xFF6FA8FF)),
  master('Master', 1900, Color(0xFFB07CE8));

  const DungeonRank(this.label, this.floor, this.color);

  final String label;
  final int floor;
  final Color color;

  static DungeonRank forRating(int rating) {
    var rank = DungeonRank.bronze;
    for (final candidate in DungeonRank.values) {
      if (rating >= candidate.floor) rank = candidate;
    }
    return rank;
  }

  /// The next rank up, or null at the top.
  DungeonRank? get next {
    final i = index + 1;
    return i < DungeonRank.values.length ? DungeonRank.values[i] : null;
  }

  /// Progress from this rank's floor toward the next, 0..1. Full at the top.
  double progressAt(int rating) {
    final ceiling = next?.floor;
    if (ceiling == null) return 1;
    final span = ceiling - floor;
    if (span <= 0) return 1;
    return ((rating - floor) / span).clamp(0.0, 1.0);
  }
}

/// A player's standing in one mode.
class DungeonRating {
  final int rating;
  final int played;
  final int won;

  /// Consecutive wins, reset by any loss. Shown as a small flourish.
  final int streak;

  const DungeonRating({
    this.rating = 1000,
    this.played = 0,
    this.won = 0,
    this.streak = 0,
  });

  DungeonRank get rank => DungeonRank.forRating(rating);

  int get lost => played - won;

  double get winRate => played == 0 ? 0 : won / played;

  DungeonRating copyWith({int? rating, int? played, int? won, int? streak}) =>
      DungeonRating(
        rating: rating ?? this.rating,
        played: played ?? this.played,
        won: won ?? this.won,
        streak: streak ?? this.streak,
      );

  Map<String, dynamic> toJson() =>
      {'r': rating, 'p': played, 'w': won, 's': streak};

  factory DungeonRating.fromJson(Map<String, dynamic> json) => DungeonRating(
        rating: json['r'] as int? ?? 1000,
        played: json['p'] as int? ?? 0,
        won: json['w'] as int? ?? 0,
        streak: json['s'] as int? ?? 0,
      );
}

/// One entry in the ranked-play log: a puzzle the player attempted, kept so it
/// can be found again and replayed with hints. Deliberately light — just enough
/// to look the puzzle up and show how it went.
class DungeonGame {
  final String puzzleId;
  final DungeonMode mode;
  final bool won;
  final int difficulty;
  final Duration elapsed;

  const DungeonGame({
    required this.puzzleId,
    required this.mode,
    required this.won,
    required this.difficulty,
    required this.elapsed,
  });

  factory DungeonGame.fromJson(Map<String, dynamic> json) => DungeonGame(
        puzzleId: json['id'] as String,
        mode: DungeonMode.values.firstWhere(
          (m) => m.storageKey == json['mode'],
          orElse: () => DungeonMode.survival,
        ),
        won: json['won'] as bool? ?? false,
        difficulty: json['difficulty'] as int? ?? 1,
        elapsed: Duration(seconds: json['seconds'] as int? ?? 0),
      );
}

/// The outcome of one ranked attempt, with the rating change it produced.
class DungeonResult {
  final DungeonMode mode;
  final bool won;
  final int puzzleDifficulty;
  final int ratingBefore;
  final int ratingAfter;
  final Duration elapsed;
  final int mistakes;

  const DungeonResult({
    required this.mode,
    required this.won,
    required this.puzzleDifficulty,
    required this.ratingBefore,
    required this.ratingAfter,
    required this.elapsed,
    required this.mistakes,
  });

  int get delta => ratingAfter - ratingBefore;

  bool get rankedUp =>
      DungeonRank.forRating(ratingAfter).index >
      DungeonRank.forRating(ratingBefore).index;

  bool get rankedDown =>
      DungeonRank.forRating(ratingAfter).index <
      DungeonRank.forRating(ratingBefore).index;
}
