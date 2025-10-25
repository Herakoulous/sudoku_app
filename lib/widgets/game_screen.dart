import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import 'game_header.dart';
import 'sudoku_grid.dart';
import 'number_pad.dart';

class GameScreen extends StatefulWidget {
  final String puzzleId;
  final int difficulty;

  const GameScreen({
    super.key,
    required this.puzzleId,
    required this.difficulty,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController controller;
  Timer? _timer;

  // NEW: Separate notifier just for the timer
  final ValueNotifier<Duration> _timerNotifier = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    controller = GameController(
      puzzleId: widget.puzzleId,
      difficulty: widget.difficulty,
    );
    _loadSavedGame();
    _startTimer();
  }

  Future<void> _loadSavedGame() async {
    await controller.loadProgress();
    _timerNotifier.value = controller.gameState.elapsedTime;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!controller.gameState.isPaused) {
        controller.gameState.elapsedTime += const Duration(seconds: 1);
        _timerNotifier.value =
            controller.gameState.elapsedTime; // Only update timer
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    controller.saveProgress();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        '===== GameScreen BUILD called ====='); // Debug: should only print once
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // Use ValueListenableBuilder - only rebuilds GameHeader when timer changes
            ValueListenableBuilder<Duration>(
              valueListenable: _timerNotifier,
              builder: (context, elapsedTime, child) {
                return GameHeader(
                  difficulty: widget.difficulty,
                  puzzleId: widget.puzzleId,
                  elapsedTime: elapsedTime,
                  onRestart: () => controller.restartPuzzle(),
                  onExit: () => Navigator.pop(context),
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RepaintBoundary(
                child: SudokuGrid(controller: controller),
              ),
            ),
            NumberPad(controller: controller),
          ],
        ),
      ),
    );
  }
}
