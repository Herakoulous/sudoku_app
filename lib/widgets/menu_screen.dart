import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/realm_config.dart';
import '../services/save_service.dart';
import '../theme/app_theme.dart';
import 'common/app_button.dart';
import 'common/app_chrome.dart';
import 'common/indicators.dart';
import 'common/pressable.dart';

/// Realm selection. The realms are browsed as a deck of tall art cards: the
/// centred card is the selection, the background dissolves to match it, and the
/// rule for that variant is spelled out before the player commits. Choosing a
/// realm should feel like choosing a place to go, not picking from a list.
class RealmSelectionScreen extends StatefulWidget {
  const RealmSelectionScreen({super.key});

  @override
  State<RealmSelectionScreen> createState() => _RealmSelectionScreenState();
}

class _RealmSelectionScreenState extends State<RealmSelectionScreen> {
  static const double _viewportFraction = 0.70;

  late final PageController _pageController = PageController(
    viewportFraction: _viewportFraction,
  );

  /// Fractional page position, driven by the controller so cards can respond
  /// continuously to the swipe rather than snapping between states.
  double _page = 0;

  int _selectedIndex = 0;

  /// realm name -> completed puzzle count.
  final Map<String, int> _completed = {};

  List<Realm> get _realms => RealmConfig.realms;

  Realm get _selectedRealm => _realms[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
    _loadProgress();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? 0;

    setState(() {
      _page = page;
      _selectedIndex = page.round().clamp(0, _realms.length - 1);
    });
  }

  Future<void> _loadProgress() async {
    for (final realm in _realms) {
      final ids = realm.puzzles.map((p) => p.id).toList();
      final stats = await SaveService.getRealmStats(ids);
      if (!mounted) return;
      setState(() => _completed[realm.name] = stats['completed'] as int);
    }
  }

  Future<void> _enterRealm() async {
    final realm = _selectedRealm;

    await Navigator.pushNamed(
      context,
      '/level-selection',
      arguments: {
        'realmName': realm.name,
        'puzzles': realm.puzzles,
      },
    );

    // Progress may have changed while the player was inside the realm.
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final realm = _selectedRealm;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AmbientBackdrop(realm: realm),

          SafeArea(
            child: Column(
              children: [
                AppTopBar(
                  title: 'Choose Your Realm',
                  onBack: () => Navigator.pop(context),
                ),

                // --- The deck ---
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _realms.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final distance = (_page - index).abs().clamp(0.0, 1.0);
                      return _RealmCard(
                        realm: _realms[index],
                        completed: _completed[_realms[index].name] ?? 0,
                        // Off-centre cards shrink and dim so the eye is never
                        // in doubt about which realm is selected.
                        scale: 1 - (distance * 0.12),
                        dim: distance * 0.55,
                        onTap: () {
                          if (index == _selectedIndex) {
                            _enterRealm();
                          } else {
                            _pageController.animateToPage(
                              index,
                              duration: AppMotion.normal,
                              curve: AppMotion.standard,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpace.md),
                _PageDots(
                  count: _realms.length,
                  page: _page,
                  color: realm.primary,
                ),
                const SizedBox(height: AppSpace.lg),

                // --- The rule for the highlighted realm ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.gutter,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: _RuleCard(
                      key: ValueKey(realm.name),
                      realm: realm,
                    ),
                  ),
                ),

                BottomActionBar(
                  child: AppButton(
                    label: 'Enter ${_shortName(realm.name)}',
                    icon: Icons.arrow_forward_rounded,
                    size: AppButtonSize.large,
                    accent: realm.primary,
                    onPressed: _enterRealm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "German Whispers Mountains" does not fit on a button; the first two words
  /// are what players actually call these places.
  String _shortName(String name) {
    final words = name.split(' ');
    return words.length <= 2 ? name : words.take(2).join(' ');
  }
}

/// Blurred artwork of the selected realm, crossfading as the deck moves. This
/// is what makes the whole screen change character per realm.
class _AmbientBackdrop extends StatelessWidget {
  final Realm realm;

  const _AmbientBackdrop({required this.realm});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.slow,
          child: ImageFiltered(
            key: ValueKey(realm.art),
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Image.asset(
              realm.art,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.ink.withValues(alpha: 0.62),
                AppColors.ink.withValues(alpha: 0.78),
                AppColors.ink.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single realm in the deck: full-bleed art, name and progress at the foot.
class _RealmCard extends StatelessWidget {
  final Realm realm;
  final int completed;
  final double scale;
  final double dim;
  final VoidCallback onTap;

  const _RealmCard({
    required this.realm,
    required this.completed,
    required this.scale,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = realm.puzzles.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final isFocused = dim < 0.1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xs,
        ),
        child: Transform.scale(
          scale: scale,
          child: Pressable(
            onTap: onTap,
            pressedScale: 0.97,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isFocused
                      ? realm.primary.withValues(alpha: 0.85)
                      : AppColors.stroke,
                  width: isFocused ? 2 : 1,
                ),
                boxShadow: isFocused
                    ? AppShadow.glow(realm.primary, opacity: 0.32, blur: 34)
                    : AppShadow.soft,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      realm.art,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: realm.primary.withValues(alpha: 0.25),
                      ),
                    ),

                    // Scrim, so the name and bar stay readable on any artwork.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.artScrim(),
                      ),
                    ),

                    // Unfocused cards recede behind a veil of ink.
                    if (dim > 0)
                      ColoredBox(
                        color: AppColors.ink.withValues(alpha: dim),
                      ),

                    Positioned(
                      left: AppSpace.md,
                      right: AppSpace.md,
                      bottom: AppSpace.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            realm.name.toUpperCase(),
                            style: AppType.displaySmall.copyWith(
                              fontSize: 16,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            realm.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.label.copyWith(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          ProgressBar(
                            progress: progress,
                            color: realm.primary,
                            height: 5,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            '$completed of $total solved',
                            style: AppType.overline.copyWith(
                              color: completed > 0
                                  ? realm.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Position indicator for the deck. The active dot stretches into a bar, which
/// reads as "you are here" more clearly than a size change alone.
class _PageDots extends StatelessWidget {
  final int count;
  final double page;
  final Color color;

  const _PageDots({
    required this.count,
    required this.page,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
        return AnimatedContainer(
          duration: AppMotion.instant,
          width: 6 + (14 * t),
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.stroke, color, t),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// Explains the realm's extra rule up front. Variant sudoku is unplayable if
/// you do not know the rule, so it is stated before entry, not after.
class _RuleCard extends StatelessWidget {
  final Realm realm;

  const _RuleCard({super.key, required this.realm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 18,
            color: realm.primary,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'THE RULE',
                  style: AppType.overline.copyWith(color: realm.primary),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(realm.rule, style: AppType.body.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
