import 'package:flutter/material.dart';

import '../models/variant_constraint.dart';
import '../theme/app_theme.dart';
import '../utils/realm_theme.dart';
import 'common/app_button.dart';

/// The "how to play" card for a puzzle: the classic rules, plus any variant
/// rules the current board uses.
///
/// Styled to sit in the same world as the rest of the app — a raised dark card
/// tinted with the realm's accent, quiet typography, and a small worked example
/// under each special rule. Kropki and XV boards draw every marker, so the card
/// spells out the negative rule too: no marker is itself a clue.
class RulesPopup extends StatelessWidget {
  final List<ConstraintType> constraintTypes;
  final RealmTheme theme;
  final VoidCallback onClose;

  const RulesPopup({
    super.key,
    required this.constraintTypes,
    required this.theme,
    required this.onClose,
  });

  Color get _accent => theme.primaryColor;

  @override
  Widget build(BuildContext context) {
    final specials = _uniqueRuleTypes(constraintTypes);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpace.gutter),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: _accent.withValues(alpha: 0.35)),
          boxShadow: [
            ...AppShadow.soft,
            BoxShadow(
              color: _accent.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('THE BASICS', style: AppType.overline),
                    const SizedBox(height: AppSpace.xs),
                    _basicsCard(),
                    if (specials.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.lg),
                      const Text('SPECIAL RULES', style: AppType.overline),
                      const SizedBox(height: AppSpace.xs),
                      for (var i = 0; i < specials.length; i++) ...[
                        _RuleCard(rule: _ruleFor(specials[i]), accent: _accent),
                        if (i < specials.length - 1)
                          const SizedBox(height: AppSpace.sm),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.lg,
              ),
              child: AppButton(
                label: 'Got it',
                icon: Icons.check_rounded,
                accent: _accent,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: _accent.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.menu_book_rounded, size: 22, color: _accent),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How to play', style: AppType.titleMedium),
                Text(theme.realmName,
                    style: AppType.label.copyWith(color: _accent)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textMuted,
            iconSize: 22,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _basicsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.grid_on_rounded,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              'Fill the 9×9 grid so every row, every column, and every 3×3 box '
              'contains the digits 1–9 exactly once.',
              style: AppType.body.copyWith(fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RULE DATA
  // ---------------------------------------------------------------------------

  /// Collapses the paired constraint types (the two Kropki dots, the two XV
  /// marks) into one representative, so each rule is described once.
  List<ConstraintType> _uniqueRuleTypes(List<ConstraintType> types) {
    final seen = <ConstraintType>{};
    for (final type in types) {
      switch (type) {
        case ConstraintType.KROPKI_WHITE:
        case ConstraintType.KROPKI_BLACK:
          seen.add(ConstraintType.KROPKI_WHITE);
          break;
        case ConstraintType.XV_X:
        case ConstraintType.XV_V:
          seen.add(ConstraintType.XV_X);
          break;
        default:
          seen.add(type);
      }
    }
    return seen.toList();
  }

  _RuleInfo _ruleFor(ConstraintType type) {
    switch (type) {
      case ConstraintType.KROPKI_WHITE:
      case ConstraintType.KROPKI_BLACK:
        return const _RuleInfo(
          icon: Icons.circle_outlined,
          title: 'Kropki dots',
          lines: [
            'A white dot joins cells that differ by 1 (consecutive).',
            'A black dot joins cells in a 2:1 ratio (one is double the other).',
          ],
          negative:
              'EVERY dot is drawn. So if there is NO dot between two touching '
              'cells, they are NOT consecutive AND NOT in a 2:1 ratio — you must '
              'use this to rule digits out. (1 and 2 are ALWAYS shown white.)',
          visual: _KropkiVisual(),
        );
      case ConstraintType.XV_X:
      case ConstraintType.XV_V:
        return const _RuleInfo(
          icon: Icons.close_rounded,
          title: 'XV pairs',
          lines: [
            'Cells joined by an X sum to 10.',
            'Cells joined by a V sum to 5.',
          ],
          negative:
              'EVERY X and V is drawn. So if a touching pair has NO mark, it '
              'does NOT sum to 5 and does NOT sum to 10 — you must use this to '
              'rule digits out.',
          visual: _XVVisual(),
        );
      case ConstraintType.THERMO:
        return const _RuleInfo(
          icon: Icons.thermostat_rounded,
          title: 'Thermometers',
          lines: [
            'Digits strictly increase from the bulb to the tip.',
            'Each cell along the thermometer is larger than the one before it.',
          ],
          visual: _ThermoVisual(),
        );
      case ConstraintType.GERMAN_WHISPERS:
        return const _RuleInfo(
          icon: Icons.show_chart_rounded,
          title: 'German whispers',
          lines: [
            'Neighbours on a green line must differ by at least 5.',
          ],
          visual: _WhispersVisual(),
        );
      case ConstraintType.SANDWICH:
        return const _RuleInfo(
          icon: Icons.tag_rounded,
          title: 'Sandwich sums',
          lines: [
            'A clue outside the grid is the sum of the digits sandwiched '
                'between the 1 and the 9 in that row or column.',
          ],
          visual: _SandwichVisual(),
        );
    }
  }

  // Static method to show the popup
  static void show(
    BuildContext context,
    List<ConstraintType> constraintTypes,
    RealmTheme theme,
    VoidCallback onClose, {
    VoidCallback? onGetHint,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RulesPopup(
        constraintTypes: constraintTypes,
        theme: theme,
        onClose: () {
          Navigator.of(context).pop();
          onClose();
        },
      ),
    );
  }
}

class _RuleInfo {
  final IconData icon;
  final String title;
  final List<String> lines;
  final String? negative;
  final Widget visual;

  const _RuleInfo({
    required this.icon,
    required this.title,
    required this.lines,
    required this.visual,
    this.negative,
  });
}

class _RuleCard extends StatelessWidget {
  final _RuleInfo rule;
  final Color accent;

  const _RuleCard({required this.rule, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(rule.icon, size: 17, color: accent),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(rule.title, style: AppType.bodyStrong),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          for (final line in rule.lines) ...[
            _bullet(line),
            const SizedBox(height: AppSpace.xxs),
          ],
          const SizedBox(height: AppSpace.xs),
          Align(alignment: Alignment.centerLeft, child: rule.visual),
          if (rule.negative != null) ...[
            const SizedBox(height: AppSpace.sm),
            _negativeNote(rule.negative!),
          ],
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: AppSpace.xs),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(text,
              style: AppType.body.copyWith(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  /// The negative rule gets a loud, warning-styled callout of its own: on these
  /// boards the *absence* of a marker is a clue, and players who miss that get
  /// stuck. Worth shouting about.
  Widget _negativeNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.priority_high_rounded,
                  size: 15, color: AppColors.warning),
              const SizedBox(width: AppSpace.xxs),
              Text('IMPORTANT — DON’T MISS THIS',
                  style: AppType.overline.copyWith(color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            text,
            style: AppType.body.copyWith(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MINI VISUALS — small worked examples, in the app's palette.
// -----------------------------------------------------------------------------

/// A single sudoku-style cell in the dark palette.
class _Cell extends StatelessWidget {
  final String value;
  const _Cell(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.stroke),
      ),
      alignment: Alignment.center,
      child: Text(value,
          style: AppType.numeric
              .copyWith(fontSize: 14, color: AppColors.textPrimary)),
    );
  }
}

class _VisualFrame extends StatelessWidget {
  final List<Widget> children;
  const _VisualFrame(this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _KropkiVisual extends StatelessWidget {
  const _KropkiVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualFrame([
      const _Cell('3'),
      _dot(Colors.white),
      const _Cell('4'),
      const SizedBox(width: AppSpace.md),
      const _Cell('2'),
      _dot(const Color(0xFF11151C), ring: true),
      const _Cell('4'),
    ]);
  }

  Widget _dot(Color color, {bool ring = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: ring ? AppColors.textSecondary : AppColors.textMuted,
              width: 1,
            ),
          ),
        ),
      );
}

class _XVVisual extends StatelessWidget {
  const _XVVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualFrame([
      const _Cell('3'),
      _mark('X'),
      const _Cell('7'),
      const SizedBox(width: AppSpace.md),
      const _Cell('2'),
      _mark('V'),
      const _Cell('3'),
    ]);
  }

  Widget _mark(String letter) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          letter,
          style: AppType.numeric.copyWith(
            fontSize: 13,
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _ThermoVisual extends StatelessWidget {
  const _ThermoVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualFrame([
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textSecondary, width: 2),
        ),
        alignment: Alignment.center,
        child: Text('2',
            style: AppType.numeric
                .copyWith(fontSize: 13, color: AppColors.textPrimary)),
      ),
      _stem(),
      const _Cell('5'),
      _stem(),
      const _Cell('7'),
    ]);
  }

  Widget _stem() => Container(
        width: 16,
        height: 3,
        color: AppColors.textMuted.withValues(alpha: 0.5),
      );
}

class _WhispersVisual extends StatelessWidget {
  const _WhispersVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualFrame([
      const _Cell('1'),
      Container(
        width: 18,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const _Cell('7'),
    ]);
  }
}

class _SandwichVisual extends StatelessWidget {
  const _SandwichVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualFrame([
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
        ),
        alignment: Alignment.center,
        child: Text('15',
            style: AppType.numeric
                .copyWith(fontSize: 11, color: AppColors.warning)),
      ),
      const SizedBox(width: AppSpace.xs),
      const _Cell('1'),
      const _Cell('5'),
      const _Cell('6'),
      const _Cell('4'),
      const _Cell('9'),
      const SizedBox(width: AppSpace.xs),
      Text('5+6+4 = 15',
          style: AppType.label.copyWith(fontSize: 11)),
    ]);
  }
}
