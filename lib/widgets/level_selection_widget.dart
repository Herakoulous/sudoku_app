import 'package:flutter/material.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/difficulty_tier.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';
import '../utils/realm_theme.dart';
import 'common/app_button.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'sudoku_grid.dart';

/// Everything known about one puzzle's place in the player's progress.
class PuzzleStatus {
  final PuzzleData puzzle;

  /// 1-based position within its realm, used as the tile label.
  final int number;
  final GameState? savedGame;
  final int? bestTimeSeconds;
  final bool isCompleted;
  final bool isLocked;

  const PuzzleStatus({
    required this.puzzle,
    required this.number,
    required this.savedGame,
    required this.bestTimeSeconds,
    required this.isCompleted,
    required this.isLocked,
  });

  bool get inProgress => savedGame != null && !isCompleted;

  /// How far through the puzzle the player is, for the tile's progress ring.
  ///
  /// Counts only the digits the *player* has entered against the cells they have
  /// to fill — the givens are excluded from both. A board that starts half full
  /// of clues is 0% solved, not 50%, so the ring reflects real effort.
  double get progress {
    final game = savedGame;
    if (game == null) return 0;

    final given = puzzle.grid;
    var toFill = 0;
    var entered = 0;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (given[r][c] != 0) continue; // a clue, not the player's to fill
        toFill++;
        if (game.currentGrid[r][c] != 0) entered++;
      }
    }
    if (toFill == 0) return 1;
    return entered / toFill;
  }
}

String formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

// =============================================================================
// PUZZLE TILE
// =============================================================================

/// One puzzle in the grid. Four states, each readable without a legend:
/// locked (dimmed padlock), untouched (plain), in progress (accent ring around
/// the number), solved (gold fill with a tick).
class PuzzleTile extends StatelessWidget {
  final PuzzleStatus status;
  final Color accent;
  final VoidCallback onTap;

  const PuzzleTile({
    super.key,
    required this.status,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = DifficultyTier.fromRating(status.puzzle.difficulty);

    return Pressable(
      onTap: status.isLocked ? null : onTap,
      pressedScale: 0.92,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: _fill(),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _border(), width: status.isCompleted ? 1.5 : 1),
            boxShadow: status.isCompleted
                ? AppShadow.glow(accent, opacity: 0.18, blur: 12)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (status.inProgress)
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: ProgressRing(
                    progress: status.progress,
                    size: double.infinity,
                    strokeWidth: 2.5,
                    color: accent,
                  ),
                ),

              if (status.isLocked)
                Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                )
              else
                Text(
                  '${status.number}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: status.isCompleted
                        ? AppColors.textOnGold
                        : AppColors.textPrimary,
                  ),
                ),

              // A tick in the corner marks a solve without hiding the number,
              // so players can still find "puzzle 34" at a glance.
              if (status.isCompleted)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: AppColors.textOnGold.withValues(alpha: 0.8),
                  ),
                ),

              // Difficulty pip, only on untouched tiles. An in-progress tile
              // already carries the accent ring, so the pip would read as a
              // stray underscore beneath the number — drop it there.
              if (!status.isLocked && !status.isCompleted && !status.inProgress)
                Positioned(
                  bottom: 5,
                  child: Container(
                    width: 14,
                    height: 3,
                    decoration: BoxDecoration(
                      color: tier.color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _fill() {
    if (status.isLocked) return AppColors.surface.withValues(alpha: 0.5);
    if (status.isCompleted) return accent;
    return AppColors.surfaceRaised;
  }

  Color _border() {
    if (status.isLocked) return AppColors.strokeSoft;
    if (status.isCompleted) return Color.lerp(accent, Colors.white, 0.3)!;
    if (status.inProgress) return accent.withValues(alpha: 0.5);
    return AppColors.stroke;
  }
}

// =============================================================================
// PUZZLE DETAIL SHEET
// =============================================================================

/// Detail view for a single puzzle, shown as a bottom sheet. A sheet rather
/// than an inline expansion: the grid below never reflows, so the tile the
/// player just tapped stays exactly where they left it.
class PuzzleDetailSheet extends StatelessWidget {
  final PuzzleStatus status;
  final String realmName;
  final VoidCallback onPlay;
  final VoidCallback onRestart;

  const PuzzleDetailSheet({
    super.key,
    required this.status,
    required this.realmName,
    required this.onPlay,
    required this.onRestart,
  });

  static Future<void> show({
    required BuildContext context,
    required PuzzleStatus status,
    required String realmName,
    required VoidCallback onPlay,
    required VoidCallback onRestart,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PuzzleDetailSheet(
        status: status,
        realmName: realmName,
        onPlay: onPlay,
        onRestart: onRestart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = RealmConfig.getPrimaryColor(realmName);
    final tier = DifficultyTier.fromRating(status.puzzle.difficulty);
    final hasProgress = status.savedGame != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.sm,
            AppSpace.gutter,
            AppSpace.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpace.md),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Puzzle ${status.number}',
                          style: AppType.titleLarge,
                        ),
                        const SizedBox(height: AppSpace.xxs),
                        DifficultyMeter(rating: status.puzzle.difficulty),
                      ],
                    ),
                  ),
                  if (status.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: AppSpace.xxs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: accent),
                          const SizedBox(width: AppSpace.xxs + 1),
                          Text(
                            'SOLVED',
                            style: AppType.overline.copyWith(color: accent),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),

              // Board preview, showing saved progress when there is any.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: AppShadow.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SudokuPreviewGrid(
                          puzzle: status.puzzle,
                          savedGame: status.savedGame,
                          realmName: realmName,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (status.bestTimeSeconds != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.xs),
                      child: StatChip(
                        icon: Icons.emoji_events_rounded,
                        value: formatSeconds(status.bestTimeSeconds!),
                        color: accent,
                      ),
                    ),
                  if (hasProgress) ...[
                    StatChip(
                      icon: Icons.timer_outlined,
                      value: formatSeconds(status.savedGame!.elapsedSeconds),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    StatChip(
                      icon: Icons.grid_view_rounded,
                      value: '${(status.progress * 100).round()}%',
                    ),
                  ],
                  if (!hasProgress && status.bestTimeSeconds == null)
                    Text(
                      '${tier.label} · not started',
                      style: AppType.label.copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),

              AppButton(
                label: hasProgress ? 'Continue' : 'Play',
                icon: Icons.play_arrow_rounded,
                size: AppButtonSize.large,
                accent: accent,
                onPressed: () {
                  Navigator.pop(context);
                  onPlay();
                },
              ),

              if (hasProgress || status.isCompleted) ...[
                const SizedBox(height: AppSpace.xs),
                AppButton(
                  label: 'Start Over',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.ghost,
                  onPressed: () {
                    Navigator.pop(context);
                    onRestart();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUDOKU PREVIEW GRID
// =============================================================================

/// Static miniature of a board, including any variant constraint markings.
/// Rendered on paper-white so it reads as a puzzle rather than as UI.
class SudokuPreviewGrid extends StatelessWidget {
  final PuzzleData puzzle;
  final GameState? savedGame;
  final String realmName;

  const SudokuPreviewGrid({
    super.key,
    required this.puzzle,
    required this.savedGame,
    required this.realmName,
  });

  @override
  Widget build(BuildContext context) {
    final grid = savedGame?.currentGrid ?? puzzle.grid;
    final theme = RealmTheme.fromRealmSync(realmName);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
      ),
      itemCount: 81,
      itemBuilder: (context, index) {
        final row = index ~/ 9;
        final col = index % 9;
        final value = grid[row][col];
        final isGiven = puzzle.grid[row][col] != 0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: _cellBorder(row, col, theme),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CellConstraintPainter(
                    constraints: puzzle.constraints,
                    row: row,
                    col: col,
                  ),
                ),
              ),
              Center(
                child: value == 0
                    ? null
                    : FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isGiven ? FontWeight.w700 : FontWeight.w500,
                              color: isGiven
                                  ? theme.textPrimary
                                  : theme.textSecondary,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Border _cellBorder(int row, int col, RealmTheme theme) {
    return Border(
      top: BorderSide(width: row % 3 == 0 ? 1.6 : 0.4, color: theme.borderColor),
      left: BorderSide(width: col % 3 == 0 ? 1.6 : 0.4, color: theme.borderColor),
      right: BorderSide(width: col == 8 ? 1.6 : 0.4, color: theme.borderColor),
      bottom: BorderSide(width: row == 8 ? 1.6 : 0.4, color: theme.borderColor),
    );
  }
}
