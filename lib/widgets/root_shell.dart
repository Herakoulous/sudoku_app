import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'archive_screen.dart';
import 'classroom_screen.dart';
import 'daily_screen.dart';
import 'dungeon_screen.dart';
import 'common/app_button.dart';
import 'common/bottom_nav.dart';
import 'main_menu_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

/// The app's home: five tabs behind a persistent bottom navigation bar.
///
/// An IndexedStack keeps every tab alive, so switching away and back does not
/// throw away scroll position or reload progress. Deeper screens — a puzzle, a
/// technique walkthrough, settings — are pushed as full routes on top, covering
/// the bar the way a modal flow should.
class RootShell extends StatefulWidget {
  final int initialTab;

  const RootShell({super.key, this.initialTab = 0});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late int _tab = widget.initialTab;

  static const List<NavDestination> _destinations = [
    NavDestination(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Play',
    ),
    NavDestination(
      icon: Icons.school_outlined,
      activeIcon: Icons.school_rounded,
      label: 'Learn',
    ),
    NavDestination(
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield_rounded,
      label: 'Dungeon',
    ),
    NavDestination(
      icon: Icons.today_outlined,
      activeIcon: Icons.today_rounded,
      label: 'Daily',
    ),
    NavDestination(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: IndexedStack(
        index: _tab,
        children: [
          const MainMenuScreen(),
          const ClassroomScreen(showBack: false),
          const DungeonScreen(),
          const DailyScreen(),
          _ProfileTab(onOpenSettings: _openSettings),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        destinations: _destinations,
        currentIndex: _tab,
        onSelected: (index) => setState(() => _tab = index),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() {}); // settings may change what tabs display
  }
}

/// The Profile tab: statistics, with a way into settings.
///
/// Statistics is the natural home for a profile — it is who the player is in the
/// game — and settings hangs off it rather than owning a tab of its own.
class _ProfileTab extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _ProfileTab({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const StatisticsScreen(showBack: false),
        // Archive and settings affordances floated into the top-right, where the
        // statistics screen leaves its trailing slot empty.
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) => AppIconButton(
                      icon: Icons.inventory_2_outlined,
                      tooltip: 'Archive',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ArchiveScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  AppIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Settings',
                    onPressed: onOpenSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
