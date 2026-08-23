import 'package:flutter/material.dart';

import '../data/solver_guides.dart';
import '../models/guide_lesson.dart';
import '../models/technique_lesson.dart';
import '../services/classroom_service.dart';
import '../theme/app_theme.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';
import 'guide_screen.dart';
import 'technique_screen.dart';

/// The classroom index: every technique, grouped into chapters, in the order
/// they build on each other.
///
/// Nothing is locked. A student who already knows half of this can jump
/// straight to what they want, while the "next up" marker gives everyone else a
/// path to follow.
class ClassroomScreen extends StatefulWidget {
  /// False when shown as a root navigation tab, where a back arrow would be
  /// wrong — there is nothing to pop to.
  final bool showBack;

  const ClassroomScreen({super.key, this.showBack = true});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  List<TechniqueLesson> _lessons = const [];
  Map<String, TechniqueProgress> _progress = const {};
  Set<String> _readGuides = const {};
  TechniqueInfo? _next;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lessons = await ClassroomService.lessons();
    final progress = await ClassroomService.progress();
    final readGuides = await ClassroomService.readGuides();
    final next = await ClassroomService.suggestedNext();

    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _progress = progress;
      _readGuides = readGuides;
      _next = next;
      _loading = false;
    });
  }

  Future<void> _openGuide(GuideLesson guide) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GuideScreen(guide: guide),
      ),
    );
    _load();
  }

  Future<void> _open(TechniqueLesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TechniqueScreen(lesson: lesson),
      ),
    );
    _load();
  }

  int get _passed {
    var count = 0;
    for (final lesson in _lessons) {
      final mark = _progress[lesson.info.id] ?? const TechniqueProgress();
      if (mark.passed(lesson.practice.length)) count++;
    }
    return count;
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
                title: 'Classroom',
                subtitle: _loading
                    ? null
                    : '$_passed of ${_lessons.length} techniques learned',
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
    final children = <Widget>[
      FadeSlideIn(child: _overview()),
      const SizedBox(height: AppSpace.xl),
      FadeSlideIn(delay: AppMotion.stagger(1), child: _foundations()),
      const SizedBox(height: AppSpace.md),
    ];

    var index = 1;
    for (final chapter in TechniqueChapter.values) {
      final inChapter =
          _lessons.where((l) => l.info.chapter == chapter).toList();
      if (inChapter.isEmpty) continue;

      final done = inChapter
          .where((l) =>
              (_progress[l.info.id] ?? const TechniqueProgress())
                  .passed(l.practice.length))
          .length;

      children.add(
        FadeSlideIn(
          delay: AppMotion.stagger(++index),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: chapter.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: chapter.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(chapter.icon, size: 17, color: chapter.color),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(chapter.title,
                              style: AppType.titleMedium.copyWith(fontSize: 15)),
                          Text(chapter.blurb,
                              style: AppType.label.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('$done/${inChapter.length}',
                        style: AppType.numeric.copyWith(
                          fontSize: 12,
                          color: done == inChapter.length && done > 0
                              ? chapter.color
                              : AppColors.textMuted,
                        )),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                for (final lesson in inChapter)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: _TechniqueRow(
                      lesson: lesson,
                      progress: _progress[lesson.info.id] ??
                          const TechniqueProgress(),
                      isNext: _next?.id == lesson.info.id,
                      onTap: () => _open(lesson),
                    ),
                  ),
                const SizedBox(height: AppSpace.md),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: children,
    );
  }

  Widget _overview() {
    final total = _lessons.length;
    final fraction = total == 0 ? 0.0 : _passed / total;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _next == null
                ? 'You have worked through every technique.'
                : 'Learn a technique, then find it yourself on real boards.',
            style: AppType.body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpace.sm),
          ProgressBar(progress: fraction),
          if (_next != null) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.gold,
                ),
                const SizedBox(width: AppSpace.xxs),
                Expanded(
                  child: Text(
                    'Next up: ${_next!.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: AppColors.gold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _foundations() {
    const sectionColor = Color(0xFF5FD3C8);
    const guides = SolverGuides.all;
    final done = guides.where((g) => _readGuides.contains(g.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: sectionColor.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  size: 17, color: sectionColor),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Foundations',
                      style: AppType.titleMedium.copyWith(fontSize: 15)),
                  Text('How to note cells, and everything a solver needs',
                      style: AppType.label.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            Text('$done/${guides.length}',
                style: AppType.numeric.copyWith(
                  fontSize: 12,
                  color: done == guides.length && done > 0
                      ? sectionColor
                      : AppColors.textMuted,
                )),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        for (final guide in guides)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: _GuideRow(
              guide: guide,
              read: _readGuides.contains(guide.id),
              onTap: () => _openGuide(guide),
            ),
          ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  final GuideLesson guide;
  final bool read;
  final VoidCallback onTap;

  const _GuideRow({
    required this.guide,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: read
                ? AppColors.success.withValues(alpha: 0.45)
                : AppColors.strokeSoft,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: (read ? AppColors.success : guide.color)
                    .withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (read ? AppColors.success : guide.color)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                read ? Icons.check_rounded : guide.icon,
                size: 15,
                color: read ? AppColors.success : guide.color,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    guide.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guide.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TechniqueRow extends StatelessWidget {
  final TechniqueLesson lesson;
  final TechniqueProgress progress;
  final bool isNext;
  final VoidCallback onTap;

  const _TechniqueRow({
    required this.lesson,
    required this.progress,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = lesson.practice.length;
    final passed = progress.passed(total);

    return Pressable(
      onTap: lesson.isTeachable ? onTap : null,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: passed
                ? AppColors.success.withValues(alpha: 0.45)
                : isNext
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : AppColors.strokeSoft,
            width: isNext ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _statusBadge(passed),
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
                          lesson.info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      if (isNext) ...[
                        const SizedBox(width: AppSpace.xs),
                        Text('NEXT UP',
                            style: AppType.overline
                                .copyWith(color: AppColors.gold, fontSize: 9)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.info.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            if (total > 0)
              Text(
                '${progress.solved}/$total',
                style: AppType.numeric.copyWith(
                  fontSize: 11,
                  color: passed ? AppColors.success : AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool passed) {
    final IconData icon;
    final Color colour;

    if (passed) {
      icon = Icons.check_rounded;
      colour = AppColors.success;
    } else if (progress.studied) {
      icon = Icons.menu_book_rounded;
      colour = AppColors.gold;
    } else {
      icon = Icons.lock_open_rounded;
      colour = AppColors.textMuted;
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: 15, color: colour),
    );
  }
}
