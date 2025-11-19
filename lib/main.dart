import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/main_menu_screen.dart';
import 'widgets/menu_screen.dart';
import 'widgets/level_selection_screen.dart';
import 'widgets/settings_screen.dart';
import 'widgets/statistics_screen.dart';
import 'data/puzzles.dart';
import 'widgets/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(SudokuRealmsApp());
  });
}

// 🔥 ADD THIS TRANSITION FUNCTION
Route createFadeSlideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.05, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOut;

      var slideTween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var fadeTween =
          Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
    transitionDuration: Duration(milliseconds: 300),
  );
}

class SudokuRealmsApp extends StatefulWidget {
  @override
  State<SudokuRealmsApp> createState() => _SudokuRealmsAppState();
}

class _SudokuRealmsAppState extends State<SudokuRealmsApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheImages();
  }

  Future<void> _precacheImages() async {
    await precacheImage(AssetImage('images/castle_background.png'), context);
    await precacheImage(AssetImage('images/castle.jpg'), context);

    final realmBackgrounds = [
      'images/realms/classic.png',
      'images/realms/kropki_forest.png',
      'images/realms/thermo_desert.png',
      'images/realms/german_whispers.png',
      'images/realms/xv_sky_islands.png',
      'images/realms/aqua_labyrinth.png',
    ];

    for (String imagePath in realmBackgrounds) {
      try {
        await precacheImage(AssetImage(imagePath), context);
      } catch (e) {
        print('Could not precache $imagePath: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Realms',
      theme: ThemeData(
        primaryColor: Color(0xFF6D9DC5),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF6D9DC5),
          secondary: Color(0xFFB4975A),
        ),
      ),
      home: MainMenuScreen(),
      debugShowCheckedModeBanner: false,
      // 🔥 REPLACE routes WITH onGenerateRoute
      onGenerateRoute: (settings) {
        Widget page;

        switch (settings.name) {
          case '/realm-selection':
            page = RealmSelectionScreen();
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
            final realmName = args['realmName'] as String;
            page = GameScreen(
              puzzleId: puzzle.id,
              difficulty: puzzle.difficulty,
              realmName: realmName,
            );
            break;

          default:
            return null;
        }

        // 🔥 Apply smooth transition to all routes
        return createFadeSlideRoute(page);
      },
    );
  }
}
