import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../theme/app_theme.dart';
import 'pressable.dart';

enum AppButtonVariant {
  /// Gold fill. One per screen — the single thing we want the player to do.
  primary,

  /// Outlined surface. Supporting actions.
  secondary,

  /// Text only. Tertiary or destructive-adjacent actions.
  ghost,
}

enum AppButtonSize { regular, large }

/// The app's button. Gold is load-bearing here: exactly one primary button
/// should be visible at a time, so the eye always knows where to go.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;

  /// Overrides the accent colour (used to tint actions per realm).
  final Color? accent;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.expand = true,
    this.accent,
  });

  double get _height => size == AppButtonSize.large ? 58 : 50;

  double get _fontSize => size == AppButtonSize.large ? 17 : 15;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tint = accent ?? AppColors.gold;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _fontSize + 4, color: _foreground(tint, enabled)),
          const SizedBox(width: AppSpace.xs),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: _foreground(tint, enabled),
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Pressable(
        onTap: onPressed == null
            ? null
            : () {
                AudioService.play(Sfx.button);
                onPressed!();
              },
        pressedScale: 0.97,
        child: Container(
          height: _height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: expand ? AppSpace.md : AppSpace.lg,
          ),
          decoration: _decoration(tint, enabled),
          child: content,
        ),
      ),
    );
  }

  Color _foreground(Color tint, bool enabled) {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.textOnGold;
      case AppButtonVariant.secondary:
        return AppColors.textPrimary;
      case AppButtonVariant.ghost:
        return tint;
    }
  }

  BoxDecoration _decoration(Color tint, bool enabled) {
    switch (variant) {
      case AppButtonVariant.primary:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(tint, Colors.white, 0.28)!,
              tint,
              Color.lerp(tint, Colors.black, 0.14)!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: enabled
              ? AppShadow.glow(tint, opacity: 0.28, blur: 20)
              : null,
        );

      case AppButtonVariant.secondary:
        return BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.stroke),
        );

      case AppButtonVariant.ghost:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
        );
    }
  }
}

/// A compact circular icon button for screen chrome (back, close, settings).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onPressed == null
          ? null
          : () {
              AudioService.play(Sfx.button);
              onPressed!();
            },
      pressedScale: 0.90,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(
          icon,
          size: size * 0.48,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
