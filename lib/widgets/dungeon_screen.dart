import 'package:flutter/material.dart';

import '../models/dungeon.dart';
import '../services/dungeon_service.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'dungeon_archive_screen.dart';
import 'dungeon_game_screen.dart';
import 'dungeon_stats_screen.dart';

/// The Dungeon tab: pick a mode and start a ranked run.
///
/// Each mode carries its own rating and rank, because Survival and Time Rush
/// reward different things — care versus nerve — and a player is often good at
/// one and not the other.
class DungeonScreen extends StatefulWidget {
  const DungeonScreen({super.key});

  @override
  State<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends State<DungeonScreen> {
  Map<DungeonMode, DungeonRating> _ratings = const {};
  bool _loading = true;
  bool _starting = false;

  /// Chosen difficulty for the next run, or null to match the player's rating.
  int? _difficulty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ratings = await DungeonService.allRatings();
    if (!mounted) return;
    setState(() {
      _ratings = ratings;
      _loading = false;
    });
  }

  Future<void> _play(DungeonMode mode) async {
    if (_starting) return;
    setState(() => _starting = true);

    final puzzle =
        await DungeonService.matchPuzzle(mode, difficulty: _difficulty);
    if (!mounted) {
      return;
    }
    setState(() => _starting = false);

    if (puzzle == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DungeonGameScreen(mode: mode, puzzle: puzzle),
      ),
    );
    _load(); // rating may have changed
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      accentGlow: AppColors.gold,
      child: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Dungeon', subtitle: 'Ranked play'),
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
        FadeSlideIn(child: _intro()),
        const SizedBox(height: AppSpace.md),
        FadeSlideIn(
          delay: AppMotion.stagger(1),
          child: _DifficultySelector(
            selected: _difficulty,
            onChanged: (value) => setState(() => _difficulty = value),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        for (var i = 0; i < DungeonMode.values.length; i++) ...[
          FadeSlideIn(
            delay: AppMotion.stagger(i + 2),
            child: _ModeCard(
              mode: DungeonMode.values[i],
              rating: _ratings[DungeonMode.values[i]] ?? const DungeonRating(),
              busy: _starting,
              onPlay: () => _play(DungeonMode.values[i]),
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        FadeSlideIn(
          delay: AppMotion.stagger(4),
          child: AppButton(
            label: 'Rating history & stats',
            icon: Icons.insights_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DungeonStatsScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        FadeSlideIn(
          delay: AppMotion.stagger(5),
          child: AppButton(
            label: 'Archive — replay past runs',
            icon: Icons.inventory_2_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DungeonArchiveScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 22, color: AppColors.gold),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              'Solve puzzles matched to your rating. Win to climb, lose ground '
              'if a run ends early.',
              style: AppType.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

}

class _ModeCard extends StatelessWidget {
  final DungeonMode mode;
  final DungeonRating rating;
  final bool busy;
  final VoidCallback onPlay;

  const _ModeCard({
    required this.mode,
    required this.rating,
    required this.busy,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final rank = rating.rank;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: rank.color.withValues(alpha: 0.35)),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rank.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: rank.color.withValues(alpha: 0.4)),
                ),
                child: Icon(mode.icon, size: 22, color: rank.color),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mode.title, style: AppType.titleMedium),
                    const SizedBox(height: 1),
                    Text(mode.tagline,
                        style: AppType.label.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              _stat('${rating.rating}', 'RATING', rank.color),
              _divider(),
              _stat(rank.label, 'RANK', rank.color),
              _divider(),
              _stat('${rating.played}', 'PLAYED', AppColors.textSecondary),
              if (rating.streak > 1) ...[
                _divider(),
                _stat('${rating.streak}', 'STREAK', AppColors.warning),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ProgressBar(
            progress: rank.progressAt(rating.rating),
            color: rank.color,
            height: 5,
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: rating.played == 0 ? 'Play your first run' : 'Play',
            icon: Icons.play_arrow_rounded,
            accent: rank.color,
            onPressed: busy ? null : onPlay,
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color colour) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppType.numeric.copyWith(fontSize: 15, color: colour)),
        Text(label, style: AppType.overline.copyWith(fontSize: 9)),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        color: AppColors.strokeSoft,
      );
}

/// Difficulty picker for the next run.
///
/// "Auto" matches the player's rating, the default. The five tiers let a player
/// deliberately reach for a harder puzzle (worth more rating) or drop to an
/// easier one — the choice is theirs, not only the matchmaker's.
class _DifficultySelector extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;

  const _DifficultySelector({required this.selected, required this.onChanged});

  /// Representative difficulty for each tier, used when a tier is chosen.
  static const List<({String label, int? difficulty, Color color})> _options = [
    (label: 'Auto', difficulty: null, color: AppColors.gold),
    (label: 'Novice', difficulty: 1, color: Color(0xFF5DD39E)),
    (label: 'Apprentice', difficulty: 3, color: Color(0xFF56A8E8)),
    (label: 'Adept', difficulty: 5, color: AppColors.gold),
    (label: 'Expert', difficulty: 7, color: Color(0xFFF08A43)),
    (label: 'Master', difficulty: 10, color: Color(0xFFE05A5A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DIFFICULTY', style: AppType.overline),
        const SizedBox(height: AppSpace.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in _options)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.xs),
                  child: _chip(option),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(({String label, int? difficulty, Color color}) option) {
    final active = selected == option.difficulty;

    return Pressable(
      onTap: () => onChanged(option.difficulty),
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? option.color.withValues(alpha: 0.18)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active
                ? option.color.withValues(alpha: 0.7)
                : AppColors.strokeSoft,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          option.label,
          style: AppType.label.copyWith(
            fontSize: 12,
            color: active ? option.color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
