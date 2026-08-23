import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common/app_chrome.dart';
import 'common/pressable.dart';

/// A tab whose feature is scaffolded but not built yet.
///
/// Honest placeholder: it names what is coming and why it is not here, rather
/// than a dead icon. Kept as a real tab so the navigation shape is settled
/// before the feature lands in it.
class ComingSoonTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final String heading;
  final String body;
  final List<String> bullets;

  const ComingSoonTab({
    super.key,
    required this.title,
    required this.icon,
    required this.heading,
    required this.body,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      accentGlow: AppColors.gold,
      child: SafeArea(
        child: Column(
          children: [
            AppTopBar(title: title),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: FadeSlideIn(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(icon, size: 34, color: AppColors.gold),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Text(
                          heading,
                          textAlign: TextAlign.center,
                          style: AppType.displaySmall,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: AppType.body,
                        ),
                        if (bullets.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.lg),
                          Container(
                            padding: const EdgeInsets.all(AppSpace.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceRaised
                                  .withValues(alpha: 0.7),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final bullet in bullets)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpace.xs,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: AppColors.gold,
                                        ),
                                        const SizedBox(width: AppSpace.sm),
                                        Expanded(
                                          child: Text(
                                            bullet,
                                            style: AppType.label.copyWith(
                                              fontSize: 12.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
