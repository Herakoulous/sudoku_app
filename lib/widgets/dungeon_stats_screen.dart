import 'package:flutter/material.dart';

import '../models/dungeon.dart';
import '../services/dungeon_service.dart';
import '../theme/app_theme.dart';
import 'common/app_chrome.dart';
import 'common/line_chart.dart';
import 'common/pressable.dart';

/// Ranked statistics: each mode's rating trend and record.
class DungeonStatsScreen extends StatefulWidget {
  const DungeonStatsScreen({super.key});

  @override
  State<DungeonStatsScreen> createState() => _DungeonStatsScreenState();
}

/// How far back the rating chart looks. History is an untimestamped sequence of
/// ratings, so "period" means a window of recent games rather than calendar time.
enum _StatsPeriod {
  last10('Last 10', 10),
  last30('Last 30', 30),
  all('All time', null);

  const _StatsPeriod(this.label, this.games);
  final String label;
  final int? games;
}

class _DungeonStatsScreenState extends State<DungeonStatsScreen> {
  /// The blue used across every rating chart, regardless of rank — the user
  /// asked for blue rather than the (sometimes grey) rank colour.
  static const Color _chartColor = AppColors.info;

  Map<DungeonMode, DungeonRating> _ratings = const {};
  Map<DungeonMode, List<int>> _history = const {};
  _StatsPeriod _period = _StatsPeriod.all;
  bool _loading = true;

  /// The last [period] games of a history, keeping the leading point so a short
  /// window still draws a line rather than a lone dot.
  List<int> _windowed(List<int> history) {
    final games = _period.games;
    if (games == null || history.length <= games + 1) return history;
    return history.sublist(history.length - games - 1);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ratings = await DungeonService.allRatings();
    final history = <DungeonMode, List<int>>{};
    for (final mode in DungeonMode.values) {
      history[mode] = await DungeonService.history(mode);
    }

    if (!mounted) return;
    setState(() {
      _ratings = ratings;
      _history = history;
      _loading = false;
    });
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
                title: 'Ranked Stats',
                onBack: () => Navigator.pop(context),
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
    final played = DungeonMode.values
        .fold<int>(0, (sum, m) => sum + (_ratings[m]?.played ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        if (played == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _empty(),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _periodFilter(),
          ),
        for (var i = 0; i < DungeonMode.values.length; i++) ...[
          FadeSlideIn(
            delay: AppMotion.stagger(i),
            child: _modeSection(DungeonMode.values[i]),
          ),
          const SizedBox(height: AppSpace.lg),
        ],
      ],
    );
  }

  Widget _periodFilter() {
    return Row(
      children: [
        const Text('PERIOD', style: AppType.overline),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final period in _StatsPeriod.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.xs),
                  child: _periodChip(period),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodChip(_StatsPeriod period) {
    final active = _period == period;
    return Pressable(
      onTap: () => setState(() => _period = period),
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? _chartColor.withValues(alpha: 0.18)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active
                ? _chartColor.withValues(alpha: 0.7)
                : AppColors.strokeSoft,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          period.label,
          style: AppType.label.copyWith(
            fontSize: 12,
            color: active ? _chartColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Text(
        'No ranked games yet. Your rating trend will appear here once you have '
        'played a few runs in either mode.',
        style: AppType.body.copyWith(fontSize: 13),
      ),
    );
  }

  Widget _modeSection(DungeonMode mode) {
    final rating = _ratings[mode] ?? const DungeonRating();
    final fullHistory = _history[mode] ?? const <int>[];
    final history = _windowed(fullHistory);
    final rank = rating.rank;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: rank.color.withValues(alpha: 0.35)),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mode.icon, size: 18, color: rank.color),
              const SizedBox(width: AppSpace.xs),
              Text(mode.title, style: AppType.titleMedium),
              const Spacer(),
              Text('${rating.rating}',
                  style: AppType.numericLarge.copyWith(
                    fontSize: 22,
                    color: rank.color,
                  )),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: rank.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text('${rank.label} rank',
                  style: AppType.label.copyWith(color: rank.color)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          LineChart(values: history, color: _chartColor),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              _stat('${rating.played}', 'PLAYED', AppColors.textSecondary),
              _divider(),
              _stat('${rating.won}', 'WON', AppColors.success),
              _divider(),
              _stat('${rating.lost}', 'LOST', AppColors.danger),
              _divider(),
              _stat('${(rating.winRate * 100).round()}%', 'WIN RATE',
                  rank.color),
            ],
          ),
          if (fullHistory.length > 1) ...[
            const SizedBox(height: AppSpace.sm),
            _peakRow(fullHistory),
          ],
        ],
      ),
    );
  }

  Widget _peakRow(List<int> history) {
    final peak = history.reduce((a, b) => a > b ? a : b);
    return Row(
      children: [
        const Icon(Icons.trending_up_rounded,
            size: 14, color: AppColors.textMuted),
        const SizedBox(width: AppSpace.xxs),
        Text('Peak $peak',
            style: AppType.label.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
            )),
      ],
    );
  }

  Widget _stat(String value, String label, Color colour) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppType.numeric.copyWith(fontSize: 15, color: colour)),
          Text(label, style: AppType.overline.copyWith(fontSize: 8.5)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        color: AppColors.strokeSoft,
      );
}
