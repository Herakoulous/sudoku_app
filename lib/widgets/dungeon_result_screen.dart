import 'package:flutter/material.dart';

import '../data/puzzles.dart';
import '../models/dungeon.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'game_screen.dart';

/// Shown after a ranked attempt: won or lost, and what it did to the rating.
class DungeonResultScreen extends StatelessWidget {
  final DungeonResult result;
  final PuzzleData puzzle;

  const DungeonResultScreen({
    super.key,
    required this.result,
    required this.puzzle,
  });

  /// Reopens the same puzzle with hints available, as an unranked session — so
  /// a player who was stumped can learn how it was meant to be solved without it
  /// touching their rating.
  void _replayWithHints(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          puzzleId: puzzle.id,
          difficulty: puzzle.difficulty,
          realmName: 'Classic Kingdom',
          ephemeral: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final won = result.won;
    final accent = won ? AppColors.success : AppColors.danger;
    final rank = DungeonRank.forRating(result.ratingAfter);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: Column(
              children: [
                const Spacer(flex: 2),
                FadeSlideIn(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: accent.withValues(alpha: 0.5)),
                        ),
                        child: Icon(
                          won
                              ? Icons.emoji_events_rounded
                              : Icons.sentiment_dissatisfied_rounded,
                          size: 42,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        won ? 'Solved!' : _lossHeadline(),
                        style: AppType.displayMedium,
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(result.mode.title, style: AppType.label),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                FadeSlideIn(
                  delay: AppMotion.stagger(1),
                  child: _ratingCard(rank),
                ),
                const SizedBox(height: AppSpace.md),
                FadeSlideIn(
                  delay: AppMotion.stagger(2),
                  child: _statsRow(),
                ),
                const Spacer(flex: 2),
                FadeSlideIn(
                  delay: AppMotion.stagger(3),
                  child: AppButton(
                    label: 'Replay with hints',
                    icon: Icons.lightbulb_outline_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _replayWithHints(context),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                FadeSlideIn(
                  delay: AppMotion.stagger(4),
                  child: AppButton(
                    label: 'Back to Dungeon',
                    icon: Icons.arrow_back_rounded,
                    size: AppButtonSize.large,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _lossHeadline() {
    if (result.mode == DungeonMode.timeRush &&
        result.elapsed >= (result.mode.timeLimit ?? Duration.zero)) {
      return 'Time up';
    }
    if (result.mode == DungeonMode.survival &&
        result.mistakes >= result.mode.mistakeLimit) {
      return 'Out of lives';
    }
    return 'Run over';
  }

  Widget _ratingCard(DungeonRank rank) {
    final delta = result.delta;
    final deltaColour = delta >= 0 ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: rank.color.withValues(alpha: 0.4)),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          if (result.rankedUp || result.rankedDown) ...[
            Text(
              result.rankedUp
                  ? 'Promoted to ${rank.label}!'
                  : 'Demoted to ${rank.label}',
              style: AppType.label.copyWith(color: rank.color),
            ),
            const SizedBox(height: AppSpace.xs),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${result.ratingAfter}', style: AppType.numericLarge),
              const SizedBox(width: AppSpace.xs),
              Text(
                '${delta >= 0 ? '+' : ''}$delta',
                style: AppType.numeric.copyWith(color: deltaColour),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: AppSpace.sm),
          ProgressBar(progress: rank.progressAt(result.ratingAfter),
              color: rank.color),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final minutes = result.elapsed.inMinutes;
    final seconds = result.elapsed.inSeconds.remainder(60);
    final time = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StatChip(icon: Icons.timer_outlined, value: time),
        const SizedBox(width: AppSpace.xs),
        StatChip(
          icon: Icons.grid_view_rounded,
          value: 'Lv ${result.puzzleDifficulty}',
        ),
        if (result.mode == DungeonMode.survival) ...[
          const SizedBox(width: AppSpace.xs),
          StatChip(
            icon: Icons.close_rounded,
            value: '${result.mistakes} slip${result.mistakes == 1 ? '' : 's'}',
            color: result.mistakes > 0 ? AppColors.danger : null,
          ),
        ],
      ],
    );
  }
}
