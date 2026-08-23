import 'package:flutter/material.dart';

import '../models/guide_lesson.dart';
import '../services/classroom_service.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';

/// Reads one classroom guide top to bottom, then lets the student mark it read.
///
/// Pure reading — no board to solve. The blocks are rendered in the same dark
/// card language as the rest of the app, with small worked illustrations drawn
/// to match the real grid so notation advice looks like the board it describes.
class GuideScreen extends StatefulWidget {
  final GuideLesson guide;

  const GuideScreen({super.key, required this.guide});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  bool _marked = false;

  Future<void> _finish() async {
    if (!_marked) {
      _marked = true;
      await ClassroomService.markGuideRead(widget.guide.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        accentGlow: guide.color,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: guide.title,
                subtitle: 'Foundations',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    0,
                    AppSpace.gutter,
                    AppSpace.md,
                  ),
                  children: [
                    for (final block in guide.blocks) ...[
                      _block(block, guide.color),
                      const SizedBox(height: AppSpace.md),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  AppSpace.sm,
                ),
                child: AppButton(
                  label: 'Mark as read',
                  icon: Icons.check_rounded,
                  accent: guide.color,
                  onPressed: _finish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(GuideBlock block, Color accent) {
    switch (block) {
      case GuideHeading(:final text):
        return Text(text, style: AppType.titleMedium.copyWith(fontSize: 16));
      case GuideText(:final text):
        return Text(
          text,
          style: AppType.body.copyWith(fontSize: 14, height: 1.5),
        );
      case GuideBullets(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items) _bullet(item, accent),
          ],
        );
      case GuideCallout():
        return _callout(block);
      case GuideDosDonts():
        return _dosDonts(block);
      case GuideDemo():
        return _demo(block);
    }
  }

  Widget _bullet(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: AppSpace.sm),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(text,
                style: AppType.body.copyWith(fontSize: 13.5, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _callout(GuideCallout c) {
    final (color, icon) = switch (c.tone) {
      GuideTone.tip => (AppColors.info, Icons.lightbulb_outline_rounded),
      GuideTone.warning => (AppColors.warning, Icons.priority_high_rounded),
      GuideTone.key => (AppColors.gold, Icons.vpn_key_rounded),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: AppSpace.xxs),
              Text(c.title, style: AppType.overline.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            c.text,
            style: AppType.body.copyWith(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dosDonts(GuideDosDonts d) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _dosDontsColumn(
            'DO',
            d.dos,
            AppColors.success,
            Icons.check_rounded,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _dosDontsColumn(
            'DON\'T',
            d.donts,
            AppColors.danger,
            Icons.close_rounded,
          ),
        ),
      ],
    );
  }

  Widget _dosDontsColumn(
    String label,
    List<String> items,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.overline.copyWith(color: color)),
          const SizedBox(height: AppSpace.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: AppSpace.xxs),
                    child: Icon(icon, size: 13, color: color),
                  ),
                  Expanded(
                    child: Text(item,
                        style: AppType.label.copyWith(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        )),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _demo(GuideDemo demo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        children: [
          _demoVisual(demo.kind),
          if (demo.caption.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              demo.caption,
              textAlign: TextAlign.center,
              style: AppType.label.copyWith(fontSize: 11.5, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _demoVisual(GuideDemoKind kind) {
    switch (kind) {
      case GuideDemoKind.centreNotes:
        return const _MiniCell(centre: {2, 5, 8}, size: 64);
      case GuideDemoKind.sideNotes:
        return const _MiniCell(side: {1, 4, 7}, size: 64);
      case GuideDemoKind.notesSideBySide:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _labelledCell('Side', const _MiniCell(side: {1, 4, 7}, size: 60)),
            const SizedBox(width: AppSpace.xl),
            _labelledCell(
                'Center', const _MiniCell(centre: {2, 5, 8}, size: 60)),
          ],
        );
      case GuideDemoKind.houseHiddenSingle:
        return const _MiniHouse(
          values: [5, 0, 8, 0, 2, 0, 9, 0, 3],
          highlight: 5, // the single empty cell that can only be the 4
          highlightValue: 4,
        );
      case GuideDemoKind.nakedPair:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiniCell(centre: {3, 7}, size: 60, highlight: true),
            SizedBox(width: AppSpace.sm),
            _MiniCell(centre: {3, 7}, size: 60, highlight: true),
          ],
        );
    }
  }

  Widget _labelledCell(String label, Widget cell) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cell,
        const SizedBox(height: AppSpace.xs),
        Text(label, style: AppType.label.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// A single sudoku cell in the dark palette, showing either centre notes or edge
/// (side) notes — the same two mark states the real board draws.
class _MiniCell extends StatelessWidget {
  final Set<int> centre;
  final Set<int> side;
  final double size;
  final bool highlight;

  const _MiniCell({
    this.centre = const {},
    this.side = const {},
    this.size = 60,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight
              ? AppColors.gold.withValues(alpha: 0.6)
              : AppColors.stroke,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: _content(),
    );
  }

  Widget _content() {
    if (side.isNotEmpty) {
      final sorted = side.toList()..sort();
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final n in sorted) _mark('$n')],
            ),
            const Spacer(),
          ],
        ),
      );
    }

    if (centre.isNotEmpty) {
      final sorted = centre.toList()..sort();
      return Center(
        child: Text(
          sorted.join(' '),
          style: AppType.numeric.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _mark(String s) => Text(
        s,
        style: AppType.numeric.copyWith(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      );
}

/// A row of nine cells — one house — for illustrating cross-hatching and hidden
/// singles.
class _MiniHouse extends StatelessWidget {
  final List<int> values;

  /// Index of the cell to highlight (an empty cell), and the digit it resolves
  /// to.
  final int highlight;
  final int highlightValue;

  const _MiniHouse({
    required this.values,
    required this.highlight,
    required this.highlightValue,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth / 9).clamp(20.0, 34.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 9; i++)
              Container(
                width: cell,
                height: cell,
                decoration: BoxDecoration(
                  color: i == highlight
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : AppColors.surfaceRaised,
                  border: Border.all(
                    color: i == highlight
                        ? AppColors.gold
                        : AppColors.stroke,
                    width: i == highlight ? 1.5 : 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  i == highlight
                      ? '$highlightValue'
                      : (values[i] == 0 ? '' : '${values[i]}'),
                  style: AppType.numeric.copyWith(
                    fontSize: cell * 0.42,
                    color: i == highlight
                        ? AppColors.gold
                        : AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
