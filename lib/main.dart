import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/menu_screen.dart';
import 'screens/game_screen.dart';
import 'models/puzzle_repository.dart';
import 'utils/beautiful_theme.dart';

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: BeautifulTheme.lightTheme,
      darkTheme: BeautifulTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MenuScreen(),
      routes: {
        '/menu': (context) => const MenuScreen(),
        '/game': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final puzzleId = args is int ? args : 3;
          final puzzle = PuzzleRepository.getPuzzleById(puzzleId);
          return GameScreen(puzzle: puzzle);
        },
      },

    );
  }
}


