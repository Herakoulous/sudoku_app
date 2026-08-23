import 'package:flutter/material.dart';

import '../data/puzzles.dart';
import '../models/dungeon.dart';
import '../services/dungeon_service.dart';
import '../theme/app_theme.dart';
import 'common/app_chrome.dart';
import 'common/pressable.dart';
import 'game_screen.dart';

/// The Dungeon archive: every ranked puzzle the player has attempted, newest
/// first, replayable with hints as an unranked session.
///
/// Ranked runs are played on ephemeral controllers (no autosave), so the game
/// itself is not resumable — but the puzzle is logged, so a player can revisit a
/// board that beat them and see how it was meant to be solved.
class DungeonArchiveScreen extends StatefulWidget {
  const DungeonArchiveScreen({super.key});

  @override
  State<DungeonArchiveScreen> createState() => _DungeonArchiveScreenState();
}

class _DungeonArchiveScreenState extends State<DungeonArchiveScreen> {
  List<DungeonGame> _games = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await DungeonService.gameLog();
    if (!mounted) return;
    setState(() {
      _games = games;
      _loading = false;
    });
  }

  void _replay(DungeonGame game) {
    final puzzle = Puzzles.getPuzzle(game.puzzleId);
    if (puzzle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That puzzle is no longer available.')),
      );
      return;
    }
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
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        accentGlow: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Ranked Archive',
                subtitle: 'Replay past runs with hints',
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
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpace.sm),
            const Text('No ranked runs yet', style: AppType.titleMedium),
            const SizedBox(height: AppSpace.xxs),
            Text(
              'Play a run in the Dungeon and it will show up here, ready to '
              'replay with hints.',
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
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      itemCount: _games.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
      itemBuilder: (context, i) => FadeSlideIn(
        delay: AppMotion.stagger(i.clamp(0, 6)),
        child: _GameTile(game: _games[i], onReplay: () => _replay(_games[i])),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final DungeonGame game;
  final VoidCallback onReplay;

  const _GameTile({required this.game, required this.onReplay});

  @override
  Widget build(BuildContext context) {
    final accent = game.won ? AppColors.success : AppColors.danger;

    return Pressable(
      onTap: onReplay,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.stroke),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(
                game.won
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                size: 20,
                color: accent,
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
                      Icon(game.mode.icon, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: AppSpace.xxs),
                      Text(game.mode.title, style: AppType.bodyStrong),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${game.won ? 'Solved' : 'Lost'} · Level ${game.difficulty}'
                    '${game.elapsed.inSeconds > 0 ? ' · ${_time(game.elapsed)}' : ''}',
                    style: AppType.label.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            const Icon(Icons.lightbulb_outline_rounded,
                size: 18, color: AppColors.gold),
          ],
        ),
      ),
    );
  }

  String _time(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
