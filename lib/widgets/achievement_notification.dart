import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/achievement.dart';
import '../theme/app_theme.dart';

/// Toast shown when an award is earned.
///
/// Finishing a hard puzzle can unlock several awards at once, so banners are
/// queued and shown one at a time rather than stacked on top of each other.
/// The queue is static because the overlay outlives any single screen — a
/// completion dialog often opens in the same frame.
class AchievementNotification {
  AchievementNotification._();

  /// Long enough to read the name and the description without rushing, which is
  /// the whole point of the banner. The previous four seconds went past before
  /// a completion dialog had finished animating in.
  static const Duration visibleDuration = Duration(seconds: 5);

  static const Duration _transition = Duration(milliseconds: 460);

  /// Beat between banners so two in a row read as two separate events.
  static const Duration _gap = Duration(milliseconds: 260);

  static final Queue<Achievement> _pending = Queue();
  static bool _showing = false;

  /// Queues [achievements] and starts draining the queue.
  static void showAll(BuildContext context, List<Achievement> achievements) {
    if (achievements.isEmpty) return;

    _pending.addAll(achievements);
    if (_showing) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _showing = true;
    _drain(overlay);
  }

  static void show(BuildContext context, Achievement achievement) =>
      showAll(context, [achievement]);

  static Future<void> _drain(OverlayState overlay) async {
    // try/finally: if draining ever throws, _showing must still be cleared or
    // no achievement banner would appear again for the rest of the session.
    try {
      await _drainLoop(overlay);
    } finally {
      _showing = false;
    }
  }

  static Future<void> _drainLoop(OverlayState overlay) async {
    while (_pending.isNotEmpty) {
      final achievement = _pending.removeFirst();
      final dismissed = Completer<void>();

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) => _AchievementBanner(
          achievement: achievement,
          onFinished: () {
            if (entry.mounted) entry.remove();
            if (!dismissed.isCompleted) dismissed.complete();
          },
        ),
      );

      // The overlay can be torn down while a banner is queued, e.g. the player
      // leaves the game screen mid-animation.
      if (!overlay.mounted) break;

      overlay.insert(entry);
      HapticFeedback.mediumImpact();

      await dismissed.future;
      if (_pending.isNotEmpty) await Future<void>.delayed(_gap);
    }
  }

  /// Clears anything queued. Used when leaving a screen so a stale banner does
  /// not appear over an unrelated one.
  ///
  /// Deliberately leaves a banner that is already on screen alone — it owns its
  /// own dismissal, and cutting it off mid-animation would leak its overlay
  /// entry.
  static void clearQueue() => _pending.clear();

  /// Full reset of the static queue state, for tests.
  @visibleForTesting
  static void resetForTesting() {
    _pending.clear();
    _showing = false;
  }
}

class _AchievementBanner extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onFinished;

  const _AchievementBanner({
    required this.achievement,
    required this.onFinished,
  });

  @override
  State<_AchievementBanner> createState() => _AchievementBannerState();
}

class _AchievementBannerState extends State<_AchievementBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AchievementNotification._transition,
  );

  Timer? _autoDismiss;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();

    _autoDismiss = Timer(AchievementNotification.visibleDuration, _leave);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;

    _autoDismiss?.cancel();

    if (mounted) await _controller.reverse();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievement;
    final tint = achievement.tier.color;

    final entrance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: fade.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  // Drops in from just above the top edge.
                  offset: Offset(0, -90 * (1 - entrance.value)),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Dismissible(
                key: ValueKey(achievement.id),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _autoDismiss?.cancel();
                  _leaving = true;
                  widget.onFinished();
                },
                child: GestureDetector(
                  onTap: _leave,
                  child: _card(achievement, tint),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Achievement achievement, Color tint) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        // Deep surface with a tier-coloured edge and bloom. Keeps the banner
        // legible over the puzzle grid, which is near-white.
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tint.withValues(alpha: 0.75), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: tint.withValues(alpha: 0.30),
            blurRadius: 26,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: tint.withValues(alpha: 0.45)),
            ),
            child: Icon(achievement.icon, color: tint, size: 24),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, size: 12, color: tint),
                    const SizedBox(width: AppSpace.xxs),
                    Text(
                      '${achievement.tier.label.toUpperCase()} UNLOCKED',
                      style: AppType.overline.copyWith(color: tint),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.titleMedium,
                ),
                const SizedBox(height: 1),
                Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
