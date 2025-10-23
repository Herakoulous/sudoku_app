// File path: lib/widgets/number_pad.dart
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';

class NumberPad extends StatefulWidget {
  final GameController controller;

  const NumberPad({
    super.key,
    required this.controller,
  });

  @override
  State<NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<NumberPad> {
  @override
  void initState() {
    super.initState();
    // Listen to controller changes so widget rebuilds when mode changes
    widget.controller.addListener(_onControllerChanged);
    print('===== Listener added to controller =====');
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // This triggers a rebuild when controller notifies listeners
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print('===== NumberPad BUILD called =====');
    print('Timestamp: ${DateTime.now()}');
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildRow1(),
          const SizedBox(height: 4),
          buildRow2(),
          const SizedBox(height: 4),
          buildRow3(),
        ],
      ),
    );
  }

  Widget buildRow1() {
    return Row(
      children: [
        buildModeButton(
          mode: GameMode.COLORING,
          icon: Icons.brush,
          label: 'Color',
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () {
            print('COLORING button pressed!');
            widget.controller.changeMode(GameMode.COLORING);
          },
        ),
        const SizedBox(width: 4),
        buildActionButton(
          label: 'Undo',
          icon: Icons.undo,
          onPressed: () => widget.controller.undo(),
          isEnabled: widget.controller.canUndo(),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 1,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(1),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 2,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(2),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 3,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(3),
        ),
        const SizedBox(width: 4),
        buildModeButton(
          mode: GameMode.NORMAL,
          icon: Icons.edit,
          label: 'Pencil',
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.changeMode(GameMode.NORMAL),
        ),
      ],
    );
  }

  Widget buildRow2() {
    return Row(
      children: [
        buildMultiButton(
          label: 'Multi',
          icon: Icons.select_all,
          onPressed: () => widget.controller.toggleMultipleSelection(),
          isActive: widget.controller.gameState.selectionMode ==
              SelectionMode.MULTIPLE,
        ),
        const SizedBox(width: 4),
        buildActionButton(
          label: 'Redo',
          icon: Icons.redo,
          onPressed: () => widget.controller.redo(),
          isEnabled: widget.controller.canRedo(),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 4,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(4),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 5,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(5),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 6,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(6),
        ),
        const SizedBox(width: 4),
        buildModeButton(
          mode: GameMode.SIDE_NOTES,
          icon: Icons.note,
          label: 'Side',
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.changeMode(GameMode.SIDE_NOTES),
        ),
      ],
    );
  }

  Widget buildRow3() {
    return Row(
      children: [
        buildActionButton(
          label: 'Help',
          icon: Icons.help,
          onPressed: () => _showRulesPopup(),
          isEnabled: true,
        ),
        const SizedBox(width: 4),
        buildActionButton(
          label: 'Erase',
          icon: Icons.clear,
          onPressed: () => widget.controller.eraseSelectedCells(),
          isEnabled: true,
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 7,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(7),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 8,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(8),
        ),
        const SizedBox(width: 4),
        buildNumberButton(
          number: 9,
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.handleNumberInput(9),
        ),
        const SizedBox(width: 4),
        buildModeButton(
          mode: GameMode.CENTER_NOTES,
          icon: Icons.center_focus_strong,
          label: 'Center',
          currentMode: widget.controller.gameState.currentMode,
          onPressed: () => widget.controller.changeMode(GameMode.CENTER_NOTES),
        ),
      ],
    );
  }

  Widget buildNumberButton({
    required int number,
    required GameMode currentMode,
    required VoidCallback onPressed,
  }) {
    final isColoringMode = currentMode == GameMode.COLORING;
    final isComplete = widget.controller.isNumberComplete(number);

    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            color: isColoringMode ? _getColorForNumber(number) : Colors.white,
          ),
          child: Center(
            child: isColoringMode
                ? null
                : Text(
                    number.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.grey : Colors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            color: isEnabled ? Colors.grey[200] : Colors.grey[100],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isEnabled ? Colors.black : Colors.grey,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? Colors.black : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMultiButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive, // This will be based on SelectionMode
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            color:
                isActive ? Colors.black : Colors.grey[200], // Black when active
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    isActive ? Colors.white : Colors.black, // White when active
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : Colors.black, // White when active
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildModeButton({
    required GameMode mode,
    required IconData icon,
    required String label,
    required GameMode currentMode,
    required VoidCallback onPressed,
  }) {
    final isActive = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            color: isActive ? Colors.black : Colors.grey[200],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : Colors.black,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRulesPopup() {
    // TODo: Show popup dialog with Sudoku rules
    // - Create AlertDialog with rules text
    // - Show using showDialog()
    // - Include large, visible text explaining Sudoku rules
  }

  Color _getColorForNumber(int number) {
    switch (number) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      case 4:
        return Colors.yellow;
      case 5:
        return Colors.orange;
      case 6:
        return Colors.purple;
      case 7:
        return Colors.pink;
      case 8:
        return Colors.grey;
      case 9:
        return Colors.brown;
      default:
        return Colors.white;
    }
  }
}
