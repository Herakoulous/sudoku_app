import 'package:flutter/material.dart';

import '../data/realm_config.dart';
import '../models/achievement.dart';
import '../models/player_stats.dart';
import '../services/achievement_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';

class StatisticsScreen extends StatefulWidget {
  /// False when shown as a root navigation tab.
  final bool showBack;

  const StatisticsScreen({super.key, this.showBack = true});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  PlayerStats _stats = const PlayerStats();
  List<AchievementStatus> _achievements = const [];
  bool _loading = true;

  int get _totalPuzzles {
    var total = 0;
    for (final realm in RealmConfig.realms) {
      total += RealmConfig.getPuzzlesForRealm(realm.name).length;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await ProgressService.stats();
    final achievements = AchievementService.statusesFor(stats);

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _achievements = achievements;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  String _clock(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Compact duration for totals: "4h 12m", "37m", "48s".
  String _span(int seconds) {
    if (seconds <= 0) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        accentGlow: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Statistics',
                onBack: widget.showBack ? () => Navigator.pop(context) : null,
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        ),
                      )
                    : _body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        FadeSlideIn(child: _headline()),
        const SizedBox(height: AppSpace.xl),

        FadeSlideIn(
          delay: AppMotion.stagger(1),
          child: const SectionLabel(label: 'At a glance'),
        ),
        const SizedBox(height: AppSpace.sm),
        FadeSlideIn(delay: AppMotion.stagger(1), child: _glanceGrid()),
        const SizedBox(height: AppSpace.xl),

        FadeSlideIn(
          delay: AppMotion.stagger(2),
          child: const SectionLabel(label: 'Realms'),
        ),
        const SizedBox(height: AppSpace.sm),
        FadeSlideIn(delay: AppMotion.stagger(2), child: _realmList()),

        const SizedBox(height: AppSpace.xl),
        FadeSlideIn(
          delay: AppMotion.stagger(4),
          child: SectionLabel(
            label: 'Achievements',
            trailing: '${_achievements.where((a) => a.unlocked).length}'
                ' / ${_achievements.length}',
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _achievementSections(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADLINE
  // ---------------------------------------------------------------------------

  Widget _headline() {
    final total = _totalPuzzles;
    final fraction = total == 0 ? 0.0 : _stats.solves / total;
    final percent = (fraction * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                progress: fraction,
                size: 76,
                strokeWidth: 5,
                center: Text(
                  '$percent%',
                  style: AppType.numeric.copyWith(fontSize: 17),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('PUZZLES SOLVED', style: AppType.overline),
                    const SizedBox(height: AppSpace.xxs),
                    // FittedBox: a four-digit count on a narrow screen must
                    // shrink rather than overflow its row.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${_stats.solves}', style: AppType.numericLarge),
                          Text(
                            ' / $total',
                            style: AppType.numeric.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    if (_stats.currentStreakDays > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpace.xxs),
                          Expanded(
                            child: Text(
                              '${_stats.currentStreakDays} day streak',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.label.copyWith(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _stats.solves == 0
                            ? 'Solve one to begin'
                            : 'No active streak',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ProgressBar(progress: fraction),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AT A GLANCE
  // ---------------------------------------------------------------------------

  Widget _glanceGrid() {
    final tiles = <Widget>[
      _statTile(Icons.star_rounded, 'Stars', '${_stats.totalStars}'),
      _statTile(Icons.schedule_rounded, 'Time played',
          _span(_stats.totalPlaySeconds)),
      _statTile(Icons.bolt_rounded, 'Best time', _clock(_stats.fastestSeconds)),
      _statTile(Icons.timeline_rounded, 'Average', _clock(_stats.averageSeconds)),
      _statTile(
          Icons.lightbulb_outline_rounded, 'Hints used', '${_stats.totalHintsUsed}'),
      _statTile(Icons.verified_rounded, 'Perfect solves', '${_stats.perfectSolves}'),
      _statTile(Icons.calendar_month_rounded, 'Days played',
          '${_stats.distinctDaysPlayed}'),
      _statTile(Icons.emoji_events_rounded, 'Longest streak',
          _stats.longestStreakDays == 0 ? '—' : '${_stats.longestStreakDays}d'),
    ];

    // Two per row, laid out with Expanded so a long value can never push the
    // row wider than the screen.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 >= tiles.length ? 0 : AppSpace.xs,
          ),
          // IntrinsicHeight gives the row a bounded height, which is what lets
          // the two tiles stretch to match each other. Plain `stretch` inside a
          // scroll view asks for infinite height and fails to lay out.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.overline.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: AppType.numeric),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REALMS
  // ---------------------------------------------------------------------------

  Widget _realmList() {
    return Column(
      children: [
        for (final realm in RealmConfig.realms)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: _realmRow(realm),
          ),
      ],
    );
  }

  Widget _realmRow(Realm realm) {
    final total = RealmConfig.getPuzzlesForRealm(realm.name).length;
    final solved = _stats.realmSolves(realm.name);
    final fraction = total == 0 ? 0.0 : solved / total;
    final done = solved >= total && total > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: done
              ? realm.primary.withValues(alpha: 0.5)
              : AppColors.strokeSoft,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: realm.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  realm.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              if (done)
                Icon(Icons.verified_rounded, size: 14, color: realm.primary),
              if (done) const SizedBox(width: AppSpace.xxs),
              Text(
                '$solved/$total',
                style: AppType.numeric.copyWith(
                  fontSize: 12,
                  color: done ? realm.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          ProgressBar(progress: fraction, color: realm.primary, height: 4),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PERSONAL BESTS
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // ACHIEVEMENTS
  // ---------------------------------------------------------------------------

  Widget _achievementSections() {
    final sections = <Widget>[];

    for (final category in AchievementCategory.values) {
      final group =
          _achievements.where((s) => s.achievement.category == category).toList();
      if (group.isEmpty) continue;

      final unlocked = group.where((s) => s.unlocked).length;

      // The category's colour is the tier of its most impressive unlocked
      // award, so a well-developed category glows in gold or purple while a
      // fresh one stays neutral — a second layer of colour beyond the tiles.
      AchievementTier? topTier;
      for (final s in group.where((s) => s.unlocked)) {
        if (topTier == null || s.achievement.tier.index > topTier.index) {
          topTier = s.achievement.tier;
        }
      }
      final accent = topTier?.color ?? AppColors.textMuted;

      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      category.label,
                      style: AppType.label.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '$unlocked/${group.length}',
                    style: AppType.overline.copyWith(
                      color: unlocked > 0 ? accent : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              _achievementGrid(group),
            ],
          ),
        ),
      );
    }

    return Column(children: sections);
  }

  Widget _achievementGrid(List<AchievementStatus> group) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Denser than before — square colour badges with no per-tile text pack
        // five or six to a row, so a category reads as a bright collection
        // rather than a sparse list. The name lives in the tap dialog.
        final columns = constraints.maxWidth < 340 ? 5 : 6;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpace.xxs + 2,
            mainAxisSpacing: AppSpace.xxs + 2,
            childAspectRatio: 1,
          ),
          itemCount: group.length,
          itemBuilder: (context, i) => _AchievementTile(
            status: group[i],
            onTap: () => _showAchievement(group[i]),
          ),
        );
      },
    );
  }

  void _showAchievement(AchievementStatus status) {
    final achievement = status.achievement;
    final hidden = achievement.secret && !status.unlocked;
    final tint =
        status.unlocked ? achievement.tier.color : AppColors.textSecondary;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.stroke),
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.xs,
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tint.withValues(alpha: 0.45)),
              ),
              child: Icon(
                hidden ? Icons.lock_outline_rounded : achievement.icon,
                color: tint,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hidden ? 'Secret Award' : achievement.name,
                    style: AppType.titleMedium,
                  ),
                  Text(
                    '${achievement.tier.label} · ${achievement.category.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.overline.copyWith(color: tint),
                  ),
                ],
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.md,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hidden
                  ? 'Keep playing to discover this one.'
                  : achievement.description,
              style: AppType.body,
            ),
            if (!hidden && achievement.target > 1) ...[
              const SizedBox(height: AppSpace.md),
              ProgressBar(progress: status.fraction, color: tint, height: 5),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${status.progress} of ${achievement.target}',
                style: AppType.label.copyWith(fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xs,
                vertical: AppSpace.xxs + 1,
              ),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status.unlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_rounded,
                    size: 14,
                    color: tint,
                  ),
                  const SizedBox(width: AppSpace.xxs + 1),
                  Text(
                    status.unlocked ? 'UNLOCKED' : 'LOCKED',
                    style: AppType.overline.copyWith(color: tint),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppType.label.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// One achievement in the grid.
///
/// Progress is drawn as a ring around the icon rather than as an extra line of
/// text. The old tile stacked icon, name and a progress label in a fixed-height
/// cell, and the third element was what pushed it into overflow.
class _AchievementTile extends StatelessWidget {
  final AchievementStatus status;
  final VoidCallback onTap;

  const _AchievementTile({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final achievement = status.achievement;
    final unlocked = status.unlocked;
    final hidden = achievement.secret && !unlocked;
    final tint = achievement.tier.color;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          final radius = side * 0.28;

          // Unlocked badges are filled with their tier colour so the grid reads
          // as a bright trophy case; locked ones stay dim, and in-progress ones
          // wear a completion ring drawn *over* the icon so it is never hidden
          // behind the badge.
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  gradient: unlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(tint, Colors.white, 0.22)!,
                            tint,
                            Color.lerp(tint, Colors.black, 0.18)!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        )
                      : null,
                  color: unlocked ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: unlocked
                        ? Color.lerp(tint, Colors.white, 0.3)!
                            .withValues(alpha: 0.6)
                        : AppColors.strokeSoft,
                  ),
                  boxShadow: unlocked
                      ? AppShadow.glow(tint, opacity: 0.4, blur: 10)
                      : null,
                ),
                child: Icon(
                  hidden ? Icons.lock_outline_rounded : achievement.icon,
                  size: side * 0.46,
                  color: unlocked
                      ? _readableOn(tint)
                      : AppColors.textMuted.withValues(alpha: 0.7),
                ),
              ),
              // The completion ring sits on top of the badge, so partial
              // progress reads clearly over the icon rather than peeking out
              // from behind it.
              if (status.inProgress)
                ProgressRing(
                  progress: status.fraction,
                  size: side,
                  strokeWidth: 3,
                  color: tint,
                ),
            ],
          );
        },
      ),
    );
  }

  /// Black or white icon, whichever reads against the tier colour — so gold and
  /// silver badges get a dark glyph and the darker tiers a light one.
  static Color _readableOn(Color background) =>
      background.computeLuminance() > 0.55 ? const Color(0xFF17120A) : Colors.white;
}
