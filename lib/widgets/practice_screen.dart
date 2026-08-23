import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/position.dart';
import '../models/technique_lesson.dart';
import '../services/classroom_service.dart';
import '../services/hint_lesson_builder.dart';
import '../theme/app_theme.dart';
import 'classroom_board.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'hint_text.dart';

/// Practice: find the technique yourself.
///
/// The student is shown a real position with its candidates and has to tap the
/// cells forming the pattern. Spotting *where* a technique applies is the skill
/// that transfers to their own puzzles — naming it, right after a lesson about
/// it, proves nothing.
///
/// Grading compares against the cells the solver named, so it can never
/// disagree with the explanation shown afterwards.
class PracticeScreen extends StatefulWidget {
  final TechniqueLesson lesson;

  const PracticeScreen({super.key, required this.lesson});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int _index = 0;
  Set<Position> _selected = {};
  bool _graded = false;
  bool _revealed = false;
  Set<int> _alreadySolved = {};

  TechniquePosition get _position => widget.lesson.practice[_index];

  /// The accepted answer nearest to the student's picks — used for the prompt
  /// count and for showing the intended pattern after a wrong guess. Any of the
  /// position's answers is correct; this is the one to reveal.
  Set<Position> get _answer => _position.closestAnswerTo(_selected);

  @override
  void initState() {
    super.initState();
    _loadSolved();
  }

  Future<void> _loadSolved() async {
    final solved =
        await ClassroomService.solvedPositions(widget.lesson.info.id);
    if (!mounted) return;

    setState(() {
      _alreadySolved = solved;
      // Open on something they have not cracked yet.
      final next = List.generate(widget.lesson.practice.length, (i) => i)
          .where((i) => !solved.contains(i))
          .toList();
      if (next.isNotEmpty) _index = next.first;
    });
  }

  bool get _isCorrect => _position.accepts(_selected);

  void _toggle(Position cell) {
    if (_graded) return;
    setState(() {
      if (!_selected.remove(cell)) _selected.add(cell);
    });
  }

  Future<void> _check() async {
    setState(() => _graded = true);

    if (_isCorrect) {
      HapticFeedback.mediumImpact();
      await ClassroomService.markPracticeSolved(widget.lesson.info.id, _index);
      if (mounted) setState(() => _alreadySolved = {..._alreadySolved, _index});
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _retry() {
    setState(() {
      _selected = {};
      _graded = false;
      _revealed = false;
    });
  }

  void _nextPosition() {
    final remaining = List.generate(widget.lesson.practice.length, (i) => i)
        .where((i) => i != _index && !_alreadySolved.contains(i))
        .toList();

    if (remaining.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _index = remaining.first;
      _selected = {};
      _graded = false;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.lesson.info;
    final total = widget.lesson.practice.length;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        accentGlow: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Find the ${info.name}',
                subtitle: '${_alreadySolved.length} of $total solved',
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
                    _prompt(info),
                    const SizedBox(height: AppSpace.md),
                    ClassroomBoard(
                      step: _position.step,
                      selected: _selected,
                      correct: _graded ? _answer : null,
                      missed: _graded
                          ? _answer.difference(_selected)
                          : null,
                      onTapCell: _toggle,
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (_graded) _verdict(),
                    if (_revealed) ...[
                      const SizedBox(height: AppSpace.sm),
                      _explanation(),
                    ],
                  ],
                ),
              ),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prompt(TechniqueInfo info) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap the ${_answer.length} cells that form the ${info.name}.',
            style: AppType.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(info.lookFor,
              style: AppType.label.copyWith(fontSize: 11.5, height: 1.35)),
        ],
      ),
    );
  }

  Widget _verdict() {
    final right = _isCorrect;
    final missed = _answer.difference(_selected).length;
    final wrong = _selected.difference(_answer).length;

    final colour = right ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colour.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            right ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 18,
            color: colour,
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              right
                  ? 'That is the pattern. Well spotted.'
                  : _missReport(missed, wrong),
              style: AppType.body.copyWith(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Says what went wrong specifically, rather than just "incorrect" — the
  /// difference between missing a cell and picking a spare one is the whole
  /// lesson.
  String _missReport(int missed, int wrong) {
    if (missed > 0 && wrong > 0) {
      return 'Not quite — $missed cell${missed == 1 ? '' : 's'} of the pattern '
          'missing, and $wrong that is not part of it.';
    }
    if (missed > 0) {
      return 'Close — $missed cell${missed == 1 ? '' : 's'} of the pattern '
          'still missing. The ones you found are marked green.';
    }
    return 'Almost — $wrong extra cell${wrong == 1 ? '' : 's'} that is not part '
        'of the pattern.';
  }

  Widget _explanation() {
    final walkthrough = HintLessonBuilder.build(_position.step);

    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW IT WORKS HERE', style: AppType.overline),
          const SizedBox(height: AppSpace.xs),
          for (final stage in walkthrough.stages)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: HintText(
                stage: stage,
                baseStyle: AppType.body.copyWith(fontSize: 13, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    final remaining = widget.lesson.practice.length - _alreadySolved.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          if (!_graded) ...[
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.xs),
              child: AppButton(
                label: 'Show me',
                variant: AppButtonVariant.secondary,
                expand: false,
                onPressed: () => setState(() {
                  _graded = true;
                  _revealed = true;
                }),
              ),
            ),
            Expanded(
              child: AppButton(
                label: 'Check',
                icon: Icons.done_rounded,
                onPressed: _selected.isEmpty ? null : _check,
              ),
            ),
          ] else ...[
            if (!_isCorrect)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: _retry,
                ),
              ),
            if (!_revealed)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: AppButton(
                  label: 'Why?',
                  variant: AppButtonVariant.ghost,
                  expand: false,
                  onPressed: () => setState(() => _revealed = true),
                ),
              ),
            Expanded(
              child: AppButton(
                label: remaining <= 0 ? 'Finish' : 'Next position',
                icon: Icons.arrow_forward_rounded,
                onPressed: _nextPosition,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
