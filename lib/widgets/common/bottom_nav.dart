import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'pressable.dart';

/// One destination in the bottom navigation.
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// The app's bottom navigation bar.
///
/// Custom rather than Material's NavigationBar so it matches the design system:
/// a floating gold-lit indicator behind the active tab, on the same deep ink as
/// everything else. Labels stay visible so a first-time player is never left
/// guessing what an icon means.
class AppBottomNav extends StatelessWidget {
  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.strokeSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = selected ? AppColors.gold : AppColors.textMuted;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.90,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xxs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.xxs + 1,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 22,
                color: colour,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
