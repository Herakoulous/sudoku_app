import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/puzzles.dart';
import 'data/realm_config.dart';
import 'services/achievement_service.dart';
import 'services/audio_service.dart';
import 'services/progress_service.dart';
import 'services/warmup_sercvice.dart';
import 'theme/app_theme.dart';
import 'widgets/classroom_screen.dart';
import 'widgets/game_screen.dart';
import 'widgets/level_selection_screen.dart';
import 'widgets/main_menu_screen.dart';
import 'widgets/root_shell.dart';
import 'widgets/menu_screen.dart';
import 'widgets/settings_screen.dart';
import 'widgets/statistics_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const SudokuRealmsApp());

    // Warms the solver up front, then pings periodically, so the first hint of
    // a session does not pay the cold-start cost.
    SolverWarmupService.startWarmup();

    _prepareProgress();
    _prepareAudio();
  });
}

/// Brings existing players onto the achievement system without a flood of
/// banners.
///
/// Order matters: build a solve log from whatever history exists, then record
/// everything already earned as seen. Skipping the second step would greet a
/// returning player with fifty notifications the next time they finished a
/// puzzle.
Future<void> _prepareProgress() async {
  try {
    await ProgressService.migrateFromCompletionFlags();
    await AchievementService.primeExistingProgress();
  } catch (e) {
    debugPrint('Could not prepare progress: $e');
  }
}

/// Warms up the audio players and, only if the player has opted in, starts the
/// background music. Both sound settings default to off, so a fresh install is
/// silent until the player turns something on.
Future<void> _prepareAudio() async {
  try {
    await AudioService.initialize();
    await AudioService.startBackgroundMusic();
  } catch (e) {
    debugPrint('Could not prepare audio: $e');
  }
}

/// Shared page transition: a short fade with a slight rise. Applied to every
/// route so navigation feels like one continuous surface.
Route createFadeSlideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class SudokuRealmsApp extends StatefulWidget {
  const SudokuRealmsApp({super.key});

  @override
  State<SudokuRealmsApp> createState() => _SudokuRealmsAppState();
}

class _SudokuRealmsAppState extends State<SudokuRealmsApp> {
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    _precacheImages();
  }

  /// Decodes the artwork ahead of time so realm cards and backdrops appear
  /// fully formed instead of popping in a frame late.
  Future<void> _precacheImages() async {
    final assets = <String>[
      'images/castle_background.png',
      'images/castle.jpg',
      ...RealmConfig.realms.map((realm) => realm.art),
    ];

    for (final asset in assets) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (e) {
        debugPrint('Could not precache $asset: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Realms',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const RootShell(),
      onGenerateRoute: (settings) {
        Widget page;

        switch (settings.name) {
          case '/realm-selection':
            page = const RealmSelectionScreen();
            break;

          case '/classroom':
            page = const ClassroomScreen();
            break;

          case '/statistics':
            page = StatisticsScreen();
            break;

          case '/settings':
            page = SettingsScreen();
            break;

          case '/level-selection':
            final args = settings.arguments as Map<String, dynamic>;
            page = LevelSelectionScreen(
              realmName: args['realmName'] as String,
              puzzles: args['puzzles'] as List<dynamic>,
            );
            break;

          case '/game':
            final args = settings.arguments as Map<String, dynamic>;
            final puzzle = args['puzzle'] as PuzzleData;
            page = GameScreen(
              puzzleId: puzzle.id,
              difficulty: puzzle.difficulty,
              realmName: args['realmName'] as String,
            );
            break;

          default:
            return null;
        }

        return createFadeSlideRoute(page);
      },
    );
  }
}
