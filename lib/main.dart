import 'package:flutter/material.dart';
import 'widgets/main_menu_screen.dart';
import 'widgets/menu_screen.dart'; // RealmSelectionScreen
import 'widgets/level_selection_screen.dart'; // 🔥 ADD THIS IMPORT
import 'data/puzzles.dart'; // For PuzzleData
import 'widgets/game_screen.dart';

void main() {
  runApp(SudokuRealmsApp());
}

class SudokuRealmsApp extends StatelessWidget {
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
      routes: {
        '/realm-selection': (context) => RealmSelectionScreen(),
        '/level-selection': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return LevelSelectionScreen(
            realmName: args['realmName'] as String,
            puzzles: args['puzzles'] as List<dynamic>,
          );
        },
        '/game': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          final puzzle = args['puzzle'] as PuzzleData;
          final realmName = args['realmName'] as String;

          return GameScreen(
            puzzleId: puzzle.id,
            difficulty: puzzle.difficulty,
            realmName: realmName, // 🔥 Pass realm to GameScreen
          );
        },
      },
    );
  }
}
