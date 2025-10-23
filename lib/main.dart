import 'package:flutter/material.dart';
import 'widgets/menu_screen.dart';

void main() {
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MenuScreen(), // Start with menu
      debugShowCheckedModeBanner: false,
    );
  }
}
