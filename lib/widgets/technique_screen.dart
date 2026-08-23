import 'package:flutter/material.dart';

import '../models/hint_lesson.dart';
import '../models/technique_lesson.dart';
import '../services/classroom_service.dart';
import '../services/hint_lesson_builder.dart';
import '../theme/app_theme.dart';
import 'classroom_board.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'common/pressable.dart';
import 'hint_text.dart';
import 'practice_screen.dart';

/// The worked example for one technique.
///
/// Deliberately the same walkthrough engine that powers in-game hints, so what
/// a student learns here is worded and illustrated exactly like the help they
/// will get mid-puzzle later.
class TechniqueScreen extends StatefulWidget {
  final TechniqueLesson lesson;

  const TechniqueScreen({super.key, required this.lesson});

  @override
  State<TechniqueScreen> createState() => _TechniqueScreenState();
}

class _TechniqueScreenState extends State<TechniqueScreen>
    with TickerProviderStateMixin {
  late final HintLesson _walkthrough =
      HintLessonBuilder.build(widget.lesson.tutorial!.step);

  late final AnimationController _stageIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  int _stage = 0;
  bool _studied = false;

  @override
  void dispose() {
    _stageIn.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool get _isLast => _stage >= _walkthrough.stages.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() => _stage++);
    _stageIn.forward(from: 0);
  }

  void _back() {
    if (_stage == 0) return;
    setState(() => _stage--);
    _stageIn.forward(from: 0);
  }

  Future<void> _finish() async {
    if (!_studied) {
      _studied = true;
      await ClassroomService.markStudied(widget.lesson.info.id);
    }
    if (!mounted) return;

    if (widget.lesson.hasPractice) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PracticeScreen(lesson: widget.lesson),
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.lesson.info;
    final stage = _walkthrough.stages[_stage];

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        accentGlow: AppColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: info.name,
                subtitle: info.chapter.title,
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
                    _lookFor(info),
                    const SizedBox(height: AppSpace.md),
                    AnimatedBuilder(
                      animation: Listenable.merge([_stageIn, _pulse]),
                      builder: (context, _) => ClassroomBoard(
                        step: widget.lesson.tutorial!.step,
                        stage: stage,
                        stageProgress: _stageIn.value,
                        pulse: _pulse.value,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _narration(stage),
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

  Widget _lookFor(TechniqueInfo info) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.search_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('WHAT TO LOOK FOR',
                    style: AppType.overline.copyWith(color: AppColors.gold)),
                const SizedBox(height: 3),
                Text(info.lookFor,
                    style: AppType.body.copyWith(fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narration(HintStage stage) {
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
          Row(
            children: [
              for (var i = 0; i < _walkthrough.stages.length; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(
                      right: i == _walkthrough.stages.length - 1 ? 0 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: i <= _stage ? AppColors.gold : AppColors.stroke,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          AnimatedSize(
            duration: AppMotion.fast,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Column(
                key: ValueKey(_stage),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  HintText(
                    stage: stage,
                    baseStyle: AppType.body.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (_isLast && _walkthrough.takeaway != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.xs),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        _walkthrough.takeaway!,
                        style: AppType.label.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          if (_stage > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.xs),
              child: AppButton(
                label: 'Back',
                variant: AppButtonVariant.secondary,
                expand: false,
                onPressed: _back,
              ),
            ),
          Expanded(
            child: AppButton(
              label: _isLast
                  ? (widget.lesson.hasPractice ? 'Try it yourself' : 'Done')
                  : 'Next',
              icon: _isLast
                  ? Icons.school_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }
}
