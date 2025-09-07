import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/menu_screen.dart';
import 'screens/sudoku_game_screen.dart';
import 'models/puzzle_repository.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MenuScreen(),
      routes: {
        '/menu': (context) => const MenuScreen(),
        '/game': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final puzzleId = args is int ? args : 1;
          final puzzle = PuzzleRepository.getPuzzleById(puzzleId);
          if (puzzle == null) {
            return const Scaffold(
              body: Center(child: Text('Puzzle not found')),
            );
          }
          return SudokuGameScreen(
            puzzleName: puzzle.title,
            difficulty: _getDifficultyFromString(puzzle.difficulty),
            initialGrid: puzzle.initialGrid,
          );
        },
      },

    );
  }

  int _getDifficultyFromString(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'very easy':
        return 1;
      case 'easy':
        return 2;
      case 'medium':
        return 4;
      case 'hard':
        return 6;
      case 'very hard':
        return 8;
      case 'expert':
        return 10;
      default:
        return 3;
    }
  }
}


