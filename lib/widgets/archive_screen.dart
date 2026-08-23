import 'package:flutter/material.dart';

import '../data/puzzles.dart';
import '../data/realm_config.dart';
import '../models/archived_game.dart';
import '../services/archive_service.dart';
import '../theme/app_theme.dart';
import 'archive_review_screen.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'game_screen.dart';
import 'level_selection_widget.dart';

/// The game archive: every puzzle the player has touched, newest first, with a
/// thumbnail of the board they built.
///
/// A finished game reopens read-only for review — with any wrong digits flagged
/// and the full move history to step through. An unfinished one resumes exactly
/// where it was left.
class ArchiveScreen extends StatefulWidget {
  final bool showBack;

  const ArchiveScreen({super.key, this.showBack = true});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<ArchivedGame> _games = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await ArchiveService.all();
    if (!mounted) return;
    setState(() {
      _games = games;
      _loading = false;
    });
  }

  Future<void> _open(ArchivedGame game) async {
    final puzzle = Puzzles.getPuzzle(game.puzzleId);
    if (puzzle == null) return;

    if (game.completed) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ArchiveReviewScreen(game: game),
        ),
      );
    } else {
      // Resume: the game screen loads the saved state (grid, notes and undo
      // history) from storage, which record() kept in step with the archive.
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            puzzleId: game.puzzleId,
            difficulty: puzzle.difficulty,
            realmName: game.realmName.isEmpty
                ? RealmConfig.classicKingdom
                : game.realmName,
          ),
        ),
      );
    }
    _load(); // state may have advanced
  }

  Future<void> _confirmClear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.stroke),
        ),
        title: Text('Clear the archive?', style: AppType.titleMedium),
        content: Text(
          'This removes every saved and finished game. It cannot be undone.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep',
                style: AppType.label.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear all',
                style: AppType.label.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (clear == true) {
      await ArchiveService.clear();
      _load();
    }
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
                title: 'Archive',
                subtitle: _loading || _games.isEmpty
                    ? null
                    : '${_games.length} game${_games.length == 1 ? '' : 's'}',
                onBack: widget.showBack ? () => Navigator.pop(context) : null,
                trailing: _games.isEmpty
                    ? null
                    : AppIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Clear archive',
                        onPressed: _confirmClear,
                      ),
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
                    : _games.isEmpty
                        ? _empty()
                        : _list(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 44, color: AppColors.textMuted),
            const SizedBox(height: AppSpace.md),
            Text('No games yet', style: AppType.titleMedium),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Puzzles you play are kept here — pick up where you left off, or '
              'look back over ones you have solved.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.xs,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      itemCount: _games.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xs),
      itemBuilder: (context, i) => FadeSlideIn(
        delay: AppMotion.stagger(i, stepMs: 30, maxMs: 240),
        child: _ArchiveRow(game: _games[i], onTap: () => _open(_games[i])),
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  final ArchivedGame game;
  final VoidCallback onTap;

  const _ArchiveRow({required this.game, required this.onTap});

  String _puzzleLabel(String id) {
    final match = RegExp(r'(\d+)$').firstMatch(id);
    return match == null ? id : 'Puzzle ${match.group(1)}';
  }

  String _time(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _ago(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = Puzzles.getPuzzle(game.puzzleId);
    final accent = game.realmName.isEmpty
        ? AppColors.gold
        : RealmConfig.getPrimaryColor(game.realmName);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: game.completed
                ? accent.withValues(alpha: 0.4)
                : AppColors.strokeSoft,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail of the board as it stands.
            SizedBox(
              width: 56,
              height: 56,
              child: puzzle == null
                  ? const SizedBox.shrink()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SudokuPreviewGrid(
                        puzzle: puzzle,
                        savedGame: game.state,
                        realmName: game.realmName.isEmpty
                            ? RealmConfig.classicKingdom
                            : game.realmName,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _puzzleLabel(game.puzzleId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.titleMedium.copyWith(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      _statusBadge(accent),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.realmName.isEmpty
                        ? RealmConfig.classicKingdom
                        : game.realmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(fontSize: 11.5),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      StatChip(
                        icon: Icons.timer_outlined,
                        value: _time(game.elapsedSeconds),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      if (game.hasMistakes)
                        StatChip(
                          icon: Icons.error_outline_rounded,
                          value: '${game.mistakes}',
                          color: AppColors.danger,
                        )
                      else if (game.inProgress)
                        StatChip(
                          icon: Icons.grid_view_rounded,
                          value: '${game.filled}/81',
                        ),
                      const Spacer(),
                      Text(
                        _ago(game.savedAt),
                        style: AppType.overline.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Icon(
              game.completed
                  ? Icons.visibility_rounded
                  : Icons.play_arrow_rounded,
              color: accent,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(Color accent) {
    final completed = game.completed;
    final colour = completed ? accent : AppColors.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(
        completed ? 'SOLVED' : 'IN PROGRESS',
        style: AppType.overline.copyWith(color: colour, fontSize: 8.5),
      ),
    );
  }
}
