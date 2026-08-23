import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'player_stats.dart';

/// Grouping for the achievements list.
enum AchievementCategory {
  progress,
  realms,
  difficulty,
  speed,
  skill,
  dedication,
  collection;

  String get label {
    switch (this) {
      case AchievementCategory.progress:
        return 'Progress';
      case AchievementCategory.realms:
        return 'Realms';
      case AchievementCategory.difficulty:
        return 'Challenge';
      case AchievementCategory.speed:
        return 'Speed';
      case AchievementCategory.skill:
        return 'Skill';
      case AchievementCategory.dedication:
        return 'Dedication';
      case AchievementCategory.collection:
        return 'Collection';
    }
  }
}

/// How much of an accomplishment an award represents. Drives its colour, so a
/// player can see at a glance whether they just did something routine or rare.
enum AchievementTier {
  bronze,
  silver,
  gold,
  legendary;

  Color get color {
    switch (this) {
      case AchievementTier.bronze:
        return const Color(0xFFC08552);
      case AchievementTier.silver:
        return const Color(0xFFB6C2D1);
      case AchievementTier.gold:
        return AppColors.gold;
      case AchievementTier.legendary:
        return const Color(0xFFB07CE8);
    }
  }

  String get label {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.legendary:
        return 'Legendary';
    }
  }
}

/// A single award.
///
/// [measure] and [target] are kept separate so the UI can show partial progress
/// ("7 / 25") instead of a bare locked padlock, which is far more motivating
/// and costs nothing extra to compute.
class Achievement {
  /// Stable key. Persisted, so never change one after release or players will
  /// be re-notified about awards they already have.
  final String id;

  final String name;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final AchievementTier tier;

  /// Value of [measure] at which the award unlocks.
  final int target;

  final int Function(PlayerStats stats) measure;

  /// Hidden until unlocked — used for a couple of playful ones so the list
  /// still holds a surprise.
  final bool secret;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.tier,
    required this.measure,
    this.target = 1,
    this.secret = false,
  });

  int progressFor(PlayerStats stats) {
    final value = measure(stats);
    return value > target ? target : value;
  }

  bool isUnlockedBy(PlayerStats stats) => measure(stats) >= target;

  /// 0..1, for progress bars.
  double fractionFor(PlayerStats stats) =>
      target <= 0 ? 1 : progressFor(stats) / target;
}

/// An achievement paired with the player's standing against it.
class AchievementStatus {
  final Achievement achievement;
  final int progress;
  final bool unlocked;

  const AchievementStatus({
    required this.achievement,
    required this.progress,
    required this.unlocked,
  });

  double get fraction => achievement.target <= 0
      ? 1
      : (progress / achievement.target).clamp(0.0, 1.0);

  /// True when there is something to show but the award is not earned yet.
  bool get inProgress => !unlocked && progress > 0;
}
