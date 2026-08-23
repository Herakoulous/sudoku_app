import 'package:flutter/material.dart';

import '../models/daily_puzzle.dart';
import '../models/difficulty_tier.dart';
import '../services/daily_service.dart';
import '../services/save_service.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'game_screen.dart';

/// The Daily tab: one hand-made puzzle a day, gentle on Monday and building to a
/// proper challenge by Sunday.
///
/// The puzzles are other people's craft, imported under licence, so the author
/// is credited on the card and again in the puzzle.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DailyPuzzle? _today;
  List<DailyPuzzle> _week = const [];
  List<DateTime> _weekDates = const [];
  List<bool> _weekSolved = const [];
  int _streak = 0;
  bool _todaySolved = false;
  String _attribution = '';
  bool _loading = true;

  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = await DailyService.today();
    final week = await DailyService.weekOf(now);
    final dates = DailyService.weekDates(now);
    final streak = await DailyService.streak();
    final solved = await DailyService.isSolved(now);
    final attribution = await DailyService.attribution();
    final weekSolved = [
      for (final date in dates) await DailyService.isSolved(date),
    ];

    if (!mounted) return;
    setState(() {
      _today = today;
      _week = week;
      _weekDates = dates;
      _weekSolved = weekSolved;
      _streak = streak;
      _todaySolved = solved;
      _attribution = attribution;
      _loading = false;
    });
  }

  Future<void> _play() {
    final todayIndex = DateTime.now().weekday - 1;
    return _playDay(todayIndex);
  }

  /// Plays the puzzle for weekday [index] within the current week. Past days and
  /// today are playable; future days are not offered.
  Future<void> _playDay(int index) async {
    if (index < 0 || index >= _week.length) return;
    final puzzle = _week[index];
    final date = index < _weekDates.length ? _weekDates[index] : DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          puzzleId: puzzle.id,
          difficulty: puzzle.difficulty,
          realmName: puzzle.realmName,
        ),
      ),
    );

    // A finished daily marks that day solved; only today's completion should
    // feed the live streak, but past days are recorded too so their dot fills in.
    if (await SaveService.isCompleted(puzzle.id)) {
      await DailyService.markSolved(date);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      accentGlow: AppColors.gold,
      child: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Puzzle of the Day', subtitle: 'One a day'),
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
                  : _today == null
                      ? _unavailable()
                      : _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unavailable() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Text(
            'The daily puzzle could not be loaded.',
            textAlign: TextAlign.center,
            style: AppType.body,
          ),
        ),
      );

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        FadeSlideIn(child: _streakBar()),
        const SizedBox(height: AppSpace.md),
        FadeSlideIn(delay: AppMotion.stagger(1), child: _weekStrip()),
        const SizedBox(height: AppSpace.lg),
        FadeSlideIn(delay: AppMotion.stagger(2), child: _todayCard()),
        const SizedBox(height: AppSpace.md),
        if (_attribution.isNotEmpty)
          FadeSlideIn(delay: AppMotion.stagger(3), child: _attributionNote()),
      ],
    );
  }

  Widget _streakBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 26,
            color: _streak > 0 ? AppColors.warning : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _streak == 0
                      ? 'Start a streak today'
                      : '$_streak day${_streak == 1 ? '' : 's'} in a row',
                  style: AppType.titleMedium.copyWith(fontSize: 16),
                ),
                Text(
                  _todaySolved
                      ? "Today's puzzle is done."
                      : 'Solve today to keep it going.',
                  style: AppType.label.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('THIS WEEK', style: AppType.overline),
            const SizedBox(width: AppSpace.xs),
            Flexible(
              child: Text('· tap a past day to play it',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  )),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++) _weekDot(i),
          ],
        ),
      ],
    );
  }

  Widget _weekDot(int index) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final isToday = index == todayIndex;
    final isPast = index < todayIndex;
    final playable = index <= todayIndex; // today and earlier
    final solved = index < _weekSolved.length && _weekSolved[index];

    final puzzle = index < _week.length ? _week[index] : null;
    final tier = puzzle == null
        ? DifficultyTier.novice
        : DifficultyTier.fromRating(puzzle.difficulty);

    final dot = Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isToday
                ? tier.color.withValues(alpha: 0.22)
                : (solved
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.surface.withValues(alpha: 0.7)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday
                  ? tier.color
                  : (solved
                      ? AppColors.success.withValues(alpha: 0.6)
                      : (isPast
                          ? AppColors.strokeSoft
                          : AppColors.strokeSoft.withValues(alpha: 0.5))),
              width: isToday ? 2 : 1,
            ),
          ),
          child: Center(
            child: solved && !isToday
                ? const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.success)
                : Text(
                    _weekdayLetters[index],
                    style: AppType.label.copyWith(
                      fontSize: 13,
                      color: isToday
                          ? tier.color
                          : (playable
                              ? AppColors.textSecondary
                              : AppColors.textMuted),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: tier.color.withValues(alpha: playable ? 1 : 0.35),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );

    if (!playable || puzzle == null) return dot;

    return Pressable(
      onTap: () => _playDay(index),
      pressedScale: 0.9,
      child: dot,
    );
  }

  Widget _todayCard() {
    final puzzle = _today!;
    final tier = DifficultyTier.fromRating(puzzle.difficulty);

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: tier.color.withValues(alpha: 0.4)),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("TODAY'S PUZZLE", style: AppType.overline),
              const Spacer(),
              if (_todaySolved)
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: AppSpace.xxs),
                    Text('SOLVED',
                        style: AppType.overline
                            .copyWith(color: AppColors.success)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xxs + 1,
                ),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: tier.color.withValues(alpha: 0.5)),
                ),
                child: Text('${puzzle.typeLabel} Sudoku',
                    style: AppType.label
                        .copyWith(color: tier.color, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          DifficultyMeter(rating: puzzle.difficulty),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: AppSpace.xxs),
              Expanded(
                child: Text(
                  'by ${puzzle.author}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: _todaySolved ? 'Play again' : 'Play',
            icon: Icons.play_arrow_rounded,
            size: AppButtonSize.large,
            accent: tier.color,
            onPressed: _play,
          ),
        ],
      ),
    );
  }

  Widget _attributionNote() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(_attribution,
                style: AppType.label.copyWith(fontSize: 11, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
