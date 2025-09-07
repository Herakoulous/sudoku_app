import 'package:flutter/material.dart';
import '../models/input_mode.dart';

class SudokuNumberPad extends StatelessWidget {
  final InputMode currentMode;
  final bool isMultiSelectMode;
  final Function(int) onNumberPressed;
  final Function(InputMode) onModeChanged;
  final VoidCallback onMultiSelectToggle;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onRules;
  final bool canUndo;
  final bool canRedo;

  const SudokuNumberPad({
    Key? key,
    required this.currentMode,
    required this.isMultiSelectMode,
    required this.onNumberPressed,
    required this.onModeChanged,
    required this.onMultiSelectToggle,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onRules,
    required this.canUndo,
    required this.canRedo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Row 1: Brush, Undo, 1, 2, 3, Pencil
          Expanded(
            child: Row(
              children: [
                _buildModeButton(
                  icon: Icons.brush,
                  isActive: currentMode == InputMode.coloring,
                  onPressed: () => onModeChanged(InputMode.coloring),
                  color: Colors.red,
                ),
                _buildActionButton(
                  icon: Icons.undo,
                  onPressed: canUndo ? onUndo : null,
                ),
                _buildNumberButton(1, Colors.red),
                _buildNumberButton(2, Colors.blue),
                _buildNumberButton(3, Colors.green),
                _buildModeButton(
                  icon: Icons.edit,
                  isActive: currentMode == InputMode.normal,
                  onPressed: () => onModeChanged(InputMode.normal),
                  color: Colors.blue,
                ),
              ],
            ),
          ),
          
          // Row 2: Multi-select, Redo, 4, 5, 6, Side Notes
          Expanded(
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.select_all,
                  isActive: isMultiSelectMode,
                  onPressed: onMultiSelectToggle,
                ),
                _buildActionButton(
                  icon: Icons.redo,
                  onPressed: canRedo ? onRedo : null,
                ),
                _buildNumberButton(4, Colors.yellow),
                _buildNumberButton(5, Colors.orange),
                _buildNumberButton(6, Colors.purple),
                _buildModeButton(
                  icon: Icons.note_alt,
                  isActive: currentMode == InputMode.sideNotes,
                  onPressed: () => onModeChanged(InputMode.sideNotes),
                  color: Colors.green,
                ),
              ],
            ),
          ),
          
          // Row 3: Rules, Clear, 7, 8, 9, Center Notes
          Expanded(
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.help,
                  onPressed: onRules,
                ),
                _buildActionButton(
                  icon: Icons.clear,
                  onPressed: onClear,
                ),
                _buildNumberButton(7, Colors.pink),
                _buildNumberButton(8, Colors.grey),
                _buildNumberButton(9, Colors.brown),
                _buildModeButton(
                  icon: Icons.center_focus_strong,
                  isActive: currentMode == InputMode.centerNotes,
                  onPressed: () => onModeChanged(InputMode.centerNotes),
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        child: ElevatedButton(
          onPressed: () => onNumberPressed(number),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
          ),
          child: currentMode == InputMode.coloring || currentMode == InputMode.color
              ? Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                )
              : Text(
                  number.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? color : Colors.grey[300],
            foregroundColor: isActive ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.blue : Colors.grey[300],
            foregroundColor: onPressed != null ? Colors.black : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
