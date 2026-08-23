import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_button.dart';

/// Standard page background: the ambient wash, optionally with realm artwork
/// bled in behind it. Art is blurred and heavily scrimmed — it sets a mood
/// without ever competing with the content on top.
class AppBackground extends StatelessWidget {
  final Widget child;

  /// Optional artwork asset shown behind the wash.
  final String? artAsset;

  /// 0 = art invisible, 1 = art at full strength.
  final double artOpacity;
  final double artBlur;

  /// Accent colour bloomed into the top of the screen.
  final Color? accentGlow;

  const AppBackground({
    super.key,
    required this.child,
    this.artAsset,
    this.artOpacity = 0.30,
    this.artBlur = 3,
    this.accentGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundWash),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (artAsset != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Art occupies the upper half and dissolves downward, so the
              // content area stays calm and readable.
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.35, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: artOpacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: artBlur,
                      sigmaY: artBlur,
                    ),
                    child: Image.asset(
                      artAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

          if (accentGlow != null)
            Positioned(
              top: -180,
              left: -60,
              right: -60,
              height: 380,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      accentGlow!.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          child,
        ],
      ),
    );
  }
}

/// Consistent page header: back affordance on the left, title centred, optional
/// trailing action. The title is optically centred by reserving the same width
/// on both sides.
class AppTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Renders the title in the display face. Reserved for realm names.
  final bool displayTitle;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.displayTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    const double slotWidth = 42;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: slotWidth,
            child: onBack == null
                ? null
                : AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                    tooltip: 'Back',
                  ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayTitle
                      ? AppType.displaySmall
                      : AppType.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.overline,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: slotWidth,
            child: trailing == null
                ? null
                : Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

/// A small all-caps section heading with an optional trailing counter.
class SectionLabel extends StatelessWidget {
  final String label;
  final String? trailing;

  const SectionLabel({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AppType.overline),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Container(height: 1, color: AppColors.strokeSoft),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpace.sm),
          Text(trailing!, style: AppType.overline),
        ],
      ],
    );
  }
}

/// Bottom action area that floats over scrolling content, fading the content
/// out behind it so nothing is ever cut off mid-line.
class BottomActionBar extends StatelessWidget {
  final Widget child;

  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.ink.withValues(alpha: 0.0),
            AppColors.ink.withValues(alpha: 0.85),
            AppColors.ink,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.xl,
            AppSpace.gutter,
            AppSpace.sm,
          ),
          child: child,
        ),
      ),
    );
  }
}
