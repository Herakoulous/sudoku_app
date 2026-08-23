import 'package:flutter/material.dart';

import '../models/hint_lesson.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/pressable.dart';
import 'hint_text.dart';

/// Walks the player through a hint one beat at a time.
///
/// The answer is deliberately the *last* thing shown. Everything before it is
/// reasoning the player could have found themselves, with the board illustrating
/// each claim — so taking a hint teaches a technique instead of just filling a
/// cell.
class HintLessonPanel extends StatelessWidget {
  final HintLesson lesson;
  final int stageIndex;

  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onApply;
  final VoidCallback onClose;

  const HintLessonPanel({
    super.key,
    required this.lesson,
    required this.stageIndex,
    required this.onNext,
    required this.onBack,
    required this.onApply,
    required this.onClose,
  });

  bool get _isLastStage => stageIndex >= lesson.stages.length - 1;

  @override
  Widget build(BuildContext context) {
    final stage = lesson.stages[stageIndex.clamp(0, lesson.stages.length - 1)];

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpace.sm,
        0,
        AppSpace.sm,
        AppSpace.xs,
      ),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.stroke),
        boxShadow: AppShadow.lifted,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpace.xs),
          _progressDots(),
          const SizedBox(height: AppSpace.sm),
          _body(stage),
          const SizedBox(height: AppSpace.sm),
          _actions(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Icon(
          lesson.isSpecific
              ? Icons.school_rounded
              : Icons.help_outline_rounded,
          size: 16,
          color: AppColors.gold,
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            lesson.technique,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.label.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Text(
          '${stageIndex + 1} / ${lesson.stages.length}',
          style: AppType.numeric.copyWith(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Pressable(
          onTap: onClose,
          pressedScale: 0.86,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  /// One dot per stage, filling as the player reads — a sense of how much
  /// reasoning is left.
  Widget _progressDots() {
    return Row(
      children: [
        for (var i = 0; i < lesson.stages.length; i++)
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              height: 3,
              margin: EdgeInsets.only(
                right: i == lesson.stages.length - 1 ? 0 : 3,
              ),
              decoration: BoxDecoration(
                color: i <= stageIndex ? AppColors.gold : AppColors.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _body(HintStage stage) {
    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey(stageIndex),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HintText(
              stage: stage,
              baseStyle: AppType.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            // The general principle lands only once the reasoning is complete,
            // so it reads as a lesson learned rather than a preamble.
            if (_isLastStage && lesson.takeaway != null) ...[
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        lesson.takeaway!,
                        style: AppType.label.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        if (stageIndex > 0)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: AppButton(
              label: 'Back',
              variant: AppButtonVariant.secondary,
              expand: false,
              onPressed: onBack,
            ),
          ),
        Expanded(
          child: _isLastStage
              ? AppButton(
                  label: lesson.isPlacement
                      ? 'Place ${lesson.placementValue}'
                      : 'Apply',
                  icon: lesson.isPlacement
                      ? Icons.edit_rounded
                      : Icons.done_all_rounded,
                  onPressed: onApply,
                )
              : AppButton(
                  label: 'Next',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onNext,
                ),
        ),
      ],
    );
  }
}
