import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/realm_config.dart';
import '../models/achievement.dart';
import '../models/difficulty_tier.dart';
import '../models/player_stats.dart';
import 'progress_service.dart';

/// The achievement catalogue, plus the bookkeeping that turns "you now qualify"
/// into "you just unlocked this".
///
/// Unlocked ids are persisted. Without that there is no way to tell a brand new
/// award from one earned last week, and the player would be shown the same
/// notification every time they finished a puzzle.
class AchievementService {
  AchievementService._();

  static const String _unlockedKey = 'achievements_unlocked';

  // ---------------------------------------------------------------------------
  // CATALOGUE
  // ---------------------------------------------------------------------------

  static final List<Achievement> all = [
    // ---------------- PROGRESS ----------------
    Achievement(
      id: 'first_solve',
      name: 'First Steps',
      description: 'Complete your first puzzle',
      icon: Icons.flag_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.bronze,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_5',
      name: 'Getting Started',
      description: 'Complete 5 puzzles',
      icon: Icons.play_circle_outline_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.bronze,
      target: 5,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_10',
      name: 'Finding Your Feet',
      description: 'Complete 10 puzzles',
      icon: Icons.directions_walk_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.bronze,
      target: 10,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_25',
      name: 'Dedicated Solver',
      description: 'Complete 25 puzzles',
      icon: Icons.grid_view_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.silver,
      target: 25,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_50',
      name: 'Champion',
      description: 'Complete 50 puzzles',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.silver,
      target: 50,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_100',
      name: 'Centurion',
      description: 'Complete 100 puzzles',
      icon: Icons.military_tech_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.gold,
      target: 100,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_200',
      name: 'Grandmaster',
      description: 'Complete 200 puzzles',
      icon: Icons.workspace_premium_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.legendary,
      target: 200,
      measure: (s) => s.solves,
    ),
    Achievement(
      id: 'solve_all',
      name: 'Completionist',
      description: 'Complete every puzzle in the game',
      icon: Icons.all_inclusive_rounded,
      category: AchievementCategory.progress,
      tier: AchievementTier.legendary,
      target: _totalPuzzleCount,
      measure: (s) => s.solves,
    ),

    // ---------------- REALMS ----------------
    Achievement(
      id: 'realms_two',
      name: 'Wanderer',
      description: 'Solve a puzzle in two different realms',
      icon: Icons.explore_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.bronze,
      target: 2,
      measure: (s) => s.solvesByRealm.length,
    ),
    Achievement(
      id: 'realms_all_touched',
      name: 'Far Traveller',
      description: 'Solve a puzzle in all six realms',
      icon: Icons.travel_explore_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.silver,
      target: 6,
      measure: (s) => s.solvesByRealm.length,
    ),
    Achievement(
      id: 'realm_any',
      name: 'Realm Master',
      description: 'Finish every puzzle in a realm',
      icon: Icons.castle_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      measure: (s) => s.completedRealms.length,
    ),
    Achievement(
      id: 'realm_classic',
      name: 'Kingdom Keeper',
      description: 'Finish all of Classic Kingdom',
      icon: Icons.shield_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      target: _realmSize(RealmConfig.classicKingdom),
      measure: (s) => s.realmSolves(RealmConfig.classicKingdom),
    ),
    Achievement(
      id: 'realm_kropki',
      name: 'Forest Warden',
      description: 'Finish all of Kropki Forest',
      icon: Icons.forest_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      target: _realmSize(RealmConfig.kropkiForest),
      measure: (s) => s.realmSolves(RealmConfig.kropkiForest),
    ),
    Achievement(
      id: 'realm_thermo',
      name: 'Desert Nomad',
      description: 'Finish all of Thermo Desert',
      icon: Icons.thermostat_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      target: _realmSize(RealmConfig.thermoDesert),
      measure: (s) => s.realmSolves(RealmConfig.thermoDesert),
    ),
    Achievement(
      id: 'realm_whispers',
      name: 'Mountain Listener',
      description: 'Finish all of German Whispers Mountains',
      icon: Icons.terrain_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      target: _realmSize(RealmConfig.germanWhispers),
      measure: (s) => s.realmSolves(RealmConfig.germanWhispers),
    ),
    Achievement(
      id: 'realm_xv',
      name: 'Sky Sailor',
      description: 'Finish all of XV Sky Islands',
      icon: Icons.cloud_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      target: _realmSize(RealmConfig.xvSkyIslands),
      measure: (s) => s.realmSolves(RealmConfig.xvSkyIslands),
    ),
    Achievement(
      id: 'realm_sandwich',
      name: 'Deep Diver',
      description: 'Finish all of Aqua Labyrinth',
      icon: Icons.water_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.gold,
      target: _realmSize(RealmConfig.aquaLabyrinth),
      measure: (s) => s.realmSolves(RealmConfig.aquaLabyrinth),
    ),
    Achievement(
      id: 'realms_all_complete',
      name: 'Six Crowns',
      description: 'Finish every realm in the game',
      icon: Icons.diamond_rounded,
      category: AchievementCategory.realms,
      tier: AchievementTier.legendary,
      target: 6,
      measure: (s) => s.completedRealms.length,
    ),

    // ---------------- CHALLENGE ----------------
    Achievement(
      id: 'tier_adept',
      name: 'Rising Talent',
      description: 'Solve an Adept puzzle',
      icon: Icons.trending_up_rounded,
      category: AchievementCategory.difficulty,
      tier: AchievementTier.bronze,
      measure: (s) => s.tierSolves(DifficultyTier.adept),
    ),
    Achievement(
      id: 'tier_expert',
      name: 'Expert Hand',
      description: 'Solve an Expert puzzle',
      icon: Icons.psychology_rounded,
      category: AchievementCategory.difficulty,
      tier: AchievementTier.silver,
      measure: (s) => s.tierSolves(DifficultyTier.expert),
    ),
    Achievement(
      id: 'tier_master',
      name: 'Master Solver',
      description: 'Solve a Master puzzle',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.difficulty,
      tier: AchievementTier.gold,
      measure: (s) => s.tierSolves(DifficultyTier.master),
    ),
    Achievement(
      id: 'tier_master_10',
      name: 'Trial by Fire',
      description: 'Solve 10 Master puzzles',
      icon: Icons.whatshot_rounded,
      category: AchievementCategory.difficulty,
      tier: AchievementTier.gold,
      target: 10,
      measure: (s) => s.tierSolves(DifficultyTier.master),
    ),
    Achievement(
      id: 'hard_25',
      name: 'No Mercy',
      description: 'Solve 25 Expert or Master puzzles',
      icon: Icons.bolt_rounded,
      category: AchievementCategory.difficulty,
      tier: AchievementTier.legendary,
      target: 25,
      measure: (s) => s.hardSolves,
    ),

    // ---------------- SPEED ----------------
    Achievement(
      id: 'speed_5min',
      name: 'Quick Wit',
      description: 'Finish a puzzle in under 5 minutes',
      icon: Icons.timer_outlined,
      category: AchievementCategory.speed,
      tier: AchievementTier.bronze,
      measure: (s) => _under(s.fastestSeconds, 300),
    ),
    Achievement(
      id: 'speed_3min',
      name: 'Lightning',
      description: 'Finish a puzzle in under 3 minutes',
      icon: Icons.flash_on_rounded,
      category: AchievementCategory.speed,
      tier: AchievementTier.silver,
      measure: (s) => _under(s.fastestSeconds, 180),
    ),
    Achievement(
      id: 'speed_90s',
      name: 'Blink of an Eye',
      description: 'Finish a puzzle in under 90 seconds',
      icon: Icons.rocket_launch_rounded,
      category: AchievementCategory.speed,
      tier: AchievementTier.gold,
      measure: (s) => _under(s.fastestSeconds, 90),
    ),
    Achievement(
      id: 'speed_average',
      name: 'Speed Demon',
      description: 'Average under 5 minutes across 10 puzzles',
      icon: Icons.speed_rounded,
      category: AchievementCategory.speed,
      tier: AchievementTier.gold,
      measure: (s) =>
          s.solves >= 10 && s.averageSeconds > 0 && s.averageSeconds < 300
              ? 1
              : 0,
    ),

    // ---------------- SKILL ----------------
    Achievement(
      id: 'nohint_1',
      name: 'Unaided',
      description: 'Solve a puzzle without a single hint',
      icon: Icons.lightbulb_outline_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.bronze,
      measure: (s) => s.noHintSolves,
    ),
    Achievement(
      id: 'nohint_10',
      name: 'Self Reliant',
      description: 'Solve 10 puzzles without hints',
      icon: Icons.self_improvement_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.silver,
      target: 10,
      measure: (s) => s.noHintSolves,
    ),
    Achievement(
      id: 'nohint_50',
      name: 'Purist',
      description: 'Solve 50 puzzles without hints',
      icon: Icons.auto_awesome_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.legendary,
      target: 50,
      measure: (s) => s.noHintSolves,
    ),
    Achievement(
      id: 'flawless_1',
      name: 'Flawless',
      description: 'Solve a puzzle without a single wrong digit',
      icon: Icons.check_circle_outline_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.bronze,
      measure: (s) => s.flawlessSolves,
    ),
    Achievement(
      id: 'flawless_10',
      name: 'Immaculate',
      description: 'Solve 10 puzzles with no mistakes',
      icon: Icons.verified_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.silver,
      target: 10,
      measure: (s) => s.flawlessSolves,
    ),
    Achievement(
      id: 'perfect_1',
      name: 'Perfect Run',
      description: 'Solve a puzzle with no hints and no mistakes',
      icon: Icons.star_outline_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.silver,
      measure: (s) => s.perfectSolves,
    ),
    Achievement(
      id: 'perfect_10',
      name: 'Untouchable',
      description: 'Ten perfect solves — no hints, no mistakes',
      icon: Icons.shield_moon_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.gold,
      target: 10,
      measure: (s) => s.perfectSolves,
    ),
    Achievement(
      id: 'perfect_master',
      name: 'Ice in the Veins',
      description: 'Solve a Master puzzle with no hints and no mistakes',
      icon: Icons.ac_unit_rounded,
      category: AchievementCategory.skill,
      tier: AchievementTier.legendary,
      measure: (s) => s.perfectMasterSolves,
    ),

    // ---------------- DEDICATION ----------------
    Achievement(
      id: 'days_2',
      name: 'Back for More',
      description: 'Play on two different days',
      icon: Icons.replay_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.bronze,
      target: 2,
      measure: (s) => s.distinctDaysPlayed,
    ),
    Achievement(
      id: 'days_10',
      name: 'Regular',
      description: 'Play on 10 different days',
      icon: Icons.calendar_month_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.silver,
      target: 10,
      measure: (s) => s.distinctDaysPlayed,
    ),
    Achievement(
      id: 'days_30',
      name: 'Devoted',
      description: 'Play on 30 different days',
      icon: Icons.event_available_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.gold,
      target: 30,
      measure: (s) => s.distinctDaysPlayed,
    ),
    Achievement(
      id: 'streak_3',
      name: 'On a Roll',
      description: 'Solve puzzles three days in a row',
      icon: Icons.local_fire_department_outlined,
      category: AchievementCategory.dedication,
      tier: AchievementTier.bronze,
      target: 3,
      measure: (s) => s.longestStreakDays,
    ),
    Achievement(
      id: 'streak_7',
      name: 'Week Warrior',
      description: 'Solve puzzles seven days in a row',
      icon: Icons.date_range_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.silver,
      target: 7,
      measure: (s) => s.longestStreakDays,
    ),
    Achievement(
      id: 'streak_14',
      name: 'Unbroken',
      description: 'Solve puzzles fourteen days in a row',
      icon: Icons.trending_flat_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.legendary,
      target: 14,
      measure: (s) => s.longestStreakDays,
    ),
    Achievement(
      id: 'time_1h',
      name: 'Settled In',
      description: 'Play for one hour in total',
      icon: Icons.hourglass_bottom_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.bronze,
      target: 3600,
      measure: (s) => s.totalPlaySeconds,
    ),
    Achievement(
      id: 'time_10h',
      name: 'Long Haul',
      description: 'Play for ten hours in total',
      icon: Icons.watch_later_outlined,
      category: AchievementCategory.dedication,
      tier: AchievementTier.gold,
      target: 36000,
      measure: (s) => s.totalPlaySeconds,
    ),
    Achievement(
      id: 'time_24h',
      name: 'Time Well Spent',
      description: 'Play for a full day in total',
      icon: Icons.hourglass_full_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.legendary,
      target: 86400,
      measure: (s) => s.totalPlaySeconds,
    ),

    // ---------------- COLLECTION ----------------
    Achievement(
      id: 'stars_100',
      name: 'Star Collector',
      description: 'Gather 100 stars',
      icon: Icons.star_border_rounded,
      category: AchievementCategory.collection,
      tier: AchievementTier.bronze,
      target: 100,
      measure: (s) => s.totalStars,
    ),
    Achievement(
      id: 'stars_250',
      name: 'Star Master',
      description: 'Gather 250 stars',
      icon: Icons.star_half_rounded,
      category: AchievementCategory.collection,
      tier: AchievementTier.silver,
      target: 250,
      measure: (s) => s.totalStars,
    ),
    Achievement(
      id: 'stars_500',
      name: 'Star Sovereign',
      description: 'Gather 500 stars',
      icon: Icons.star_rounded,
      category: AchievementCategory.collection,
      tier: AchievementTier.gold,
      target: 500,
      measure: (s) => s.totalStars,
    ),
    Achievement(
      id: 'stars_1000',
      name: 'Constellation',
      description: 'Gather 1000 stars',
      icon: Icons.auto_awesome_mosaic_rounded,
      category: AchievementCategory.collection,
      tier: AchievementTier.legendary,
      target: 1000,
      measure: (s) => s.totalStars,
    ),
    Achievement(
      id: 'promote_25',
      name: 'Pencil Pusher',
      description: 'Confirm 25 notes with a double tap',
      icon: Icons.edit_note_rounded,
      category: AchievementCategory.collection,
      tier: AchievementTier.bronze,
      target: 25,
      measure: (s) => s.notePromotions,
    ),

    // ---------------- SECRETS ----------------
    Achievement(
      id: 'early_bird',
      name: 'Early Bird',
      description: 'Finish a puzzle before 9 in the morning',
      icon: Icons.wb_twilight_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.silver,
      secret: true,
      measure: (s) => s.earlyBirdSolves,
    ),
    Achievement(
      id: 'night_owl',
      name: 'Night Owl',
      description: 'Finish a puzzle after 10 at night',
      icon: Icons.nightlight_round,
      category: AchievementCategory.dedication,
      tier: AchievementTier.silver,
      secret: true,
      measure: (s) => s.nightOwlSolves,
    ),
    Achievement(
      id: 'midnight_oil',
      name: 'Midnight Oil',
      description: 'Finish a puzzle between 1 and 4 in the morning',
      icon: Icons.bedtime_rounded,
      category: AchievementCategory.dedication,
      tier: AchievementTier.gold,
      secret: true,
      measure: (s) => s.midnightSolves,
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // EVALUATION
  // ---------------------------------------------------------------------------

  /// Current standing against every award, catalogue order.
  static Future<List<AchievementStatus>> statuses() async {
    final stats = await ProgressService.stats();
    return statusesFor(stats);
  }

  static List<AchievementStatus> statusesFor(PlayerStats stats) {
    return [
      for (final achievement in all)
        AchievementStatus(
          achievement: achievement,
          progress: achievement.progressFor(stats),
          unlocked: achievement.isUnlockedBy(stats),
        ),
    ];
  }

  /// Re-evaluates everything and returns only awards that were not already
  /// recorded as unlocked, marking them as recorded before returning.
  ///
  /// Safe to call more than once for the same event: the second call returns an
  /// empty list, so a rebuild cannot double-notify.
  static Future<List<Achievement>> collectNewlyUnlocked() async {
    final stats = await ProgressService.stats();
    final known = await unlockedIds();

    final fresh = <Achievement>[];
    for (final achievement in all) {
      if (known.contains(achievement.id)) continue;
      if (achievement.isUnlockedBy(stats)) fresh.add(achievement);
    }

    if (fresh.isEmpty) return const [];

    await _persistUnlocked({...known, ...fresh.map((a) => a.id)});

    // Least impressive first, so the biggest award lands last and is the one
    // left on screen in the player's memory.
    fresh.sort((a, b) => a.tier.index.compareTo(b.tier.index));
    return fresh;
  }

  /// Records everything currently earned without returning it.
  ///
  /// Called once on first launch after this system ships, so a player with
  /// existing progress is not buried under fifty notifications at once.
  static Future<void> primeExistingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_unlockedKey)) return;

    final stats = await ProgressService.stats();
    await _persistUnlocked({
      for (final a in all)
        if (a.isUnlockedBy(stats)) a.id,
    });
  }

  static Future<Set<String>> unlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_unlockedKey) ?? const []).toSet();
  }

  static Future<void> _persistUnlocked(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, ids.toList());
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unlockedKey);
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// 1 when the best time beats [limit], 0 otherwise. A fastest time of 0 means
  /// nothing has been solved yet and must not count as infinitely fast.
  static int _under(int fastestSeconds, int limit) =>
      fastestSeconds > 0 && fastestSeconds < limit ? 1 : 0;

  static int _realmSize(String realmName) =>
      RealmConfig.getPuzzlesForRealm(realmName).length;

  static int get _totalPuzzleCount {
    var total = 0;
    for (final realm in RealmConfig.realms) {
      total += RealmConfig.getPuzzlesForRealm(realm.name).length;
    }
    return total;
  }
}
