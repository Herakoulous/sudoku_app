import 'package:flutter/material.dart';
import '../models/input_mode.dart';

class NumberPad extends StatefulWidget {
  final InputMode currentMode;
  final bool isMultiSelectActive;
  final Function(int) onNumberPressed;
  final Function(int) onColorPressed;
  final VoidCallback onClearPressed;
  final Function(InputMode) onModeChanged;
  final VoidCallback onMultiSelectToggle;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final Set<String> selectedCells;

  const NumberPad({
    Key? key,
    required this.currentMode,
    required this.isMultiSelectActive,
    required this.onNumberPressed,
    required this.onColorPressed,
    required this.onClearPressed,
    required this.onModeChanged,
    required this.onMultiSelectToggle,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.selectedCells,
  }) : super(key: key);

  @override
  State<NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<NumberPad> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final buttonSize = (width - 70) / 6; // 6 buttons per row
    final buttonHeight = buttonSize * 1.375; // Made 25% taller (1.1 * 1.25)

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
          // Row 1: Color/Pen, Undo, Numbers 1-3, Normal Mode
          _buildRow([
            _colorPenButton(buttonSize, buttonHeight),
            _undoButton(buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(1, Colors.red, buttonSize, buttonHeight)
                : _numberButton(1, buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(2, Colors.blue, buttonSize, buttonHeight)
                : _numberButton(2, buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(3, Colors.green, buttonSize, buttonHeight)
                : _numberButton(3, buttonSize, buttonHeight),
            _normalModeButton(buttonSize, buttonHeight),
          ]),

          const SizedBox(height: 6),

          // Row 2: Multi-select, Redo, Numbers 4-6, Corner Mode
          _buildRow([
            _multiSelectButton(buttonSize, buttonHeight),
            _redoButton(buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(4, Colors.yellow, buttonSize, buttonHeight)
                : _numberButton(4, buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(5, Colors.orange, buttonSize, buttonHeight)
                : _numberButton(5, buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(6, Colors.purple, buttonSize, buttonHeight)
                : _numberButton(6, buttonSize, buttonHeight),
            _cornerModeButton(buttonSize, buttonHeight),
          ]),

          const SizedBox(height: 6),

          // Row 3: Help, Erase, Numbers 7-9, Center Mode
          _buildRow([
            _helpButton(buttonSize, buttonHeight),
            _backspaceButton(buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(7, Colors.pink, buttonSize, buttonHeight)
                : _numberButton(7, buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(8, Colors.grey, buttonSize, buttonHeight)
                : _numberButton(8, buttonSize, buttonHeight),
            widget.currentMode == InputMode.color
                ? _colorButton(9, Colors.brown, buttonSize, buttonHeight)
                : _numberButton(9, buttonSize, buttonHeight),
            _centerModeButton(buttonSize, buttonHeight),
          ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Expanded(child: Row(children: children));
  }

  Widget _baseButton({
    required double width,
    required double height,
    required VoidCallback onPressed,
    required Widget child,
    required Color bgColor,
    bool isActive = false,
    bool isEnabled = true,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        height: height,
        child: GestureDetector(
          onTap: isEnabled ? onPressed : null,
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF6366F1) : bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isEnabled ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: DefaultTextStyle(
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Row 1 buttons
  Widget _colorPenButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () => widget.onModeChanged(InputMode.color),
      bgColor: Colors.white,
      isActive: widget.currentMode == InputMode.color,
      child: Transform.rotate(
        angle: -0.3,
        child: const Icon(Icons.brush, size: 18),
      ),
    );
  }

  Widget _undoButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: widget.onUndo,
      bgColor: Colors.white,
      isEnabled: widget.canUndo,
      child: const Icon(Icons.undo, size: 20),
    );
  }

  Widget _normalModeButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () => widget.onModeChanged(InputMode.normal),
      bgColor: Colors.white,
      isActive: widget.currentMode == InputMode.normal,
      child: const Icon(Icons.create_outlined, size: 18),
    );
  }

  // Row 2 buttons
  Widget _multiSelectButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: widget.onMultiSelectToggle,
      bgColor: Colors.white,
      isActive: widget.isMultiSelectActive,
      child: const Icon(Icons.select_all, size: 18),
    );
  }

  Widget _redoButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: widget.onRedo,
      bgColor: Colors.white,
      isEnabled: widget.canRedo,
      child: const Icon(Icons.redo, size: 20),
    );
  }

  Widget _cornerModeButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () => widget.onModeChanged(InputMode.corner),
      bgColor: Colors.white,
      isActive: widget.currentMode == InputMode.corner,
      child: Stack(
        children: [
          const Positioned(
            top: 4,
            left: 6,
            child: Text(
              '8',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const Positioned(
            bottom: 4,
            left: 6,
            child: Text(
              '1',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const Positioned(
            bottom: 4,
            right: 6,
            child: Text(
              '2',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Row 3 buttons
  Widget _helpButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () {
        _showHelpDialog();
      },
      bgColor: Colors.white,
      child: const Icon(Icons.help_outline, size: 20),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('How to Play'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRuleSection(
                  'Classic Sudoku Rules',
                  'Fill each row, column, and 3x3 box with numbers 1-9 without repeating any number.',
                ),
                const SizedBox(height: 16),
                _buildRuleSection(
                  'Input Modes',
                  '• Normal: Enter numbers\n• Corner: Add corner marks (1-9)\n• Center: Add center marks (1-9)\n• Color: Apply color highlighting\n• Multi-select: Select multiple cells',
                ),
                const SizedBox(height: 16),
                _buildRuleSection(
                  'Controls',
                  '• Tap to select a cell\n• Drag to select multiple cells\n• Use number pad to input values\n• Undo/Redo buttons for mistakes',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRuleSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _backspaceButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: widget.onClearPressed,
      bgColor: Colors.white,
      child: const Icon(Icons.backspace_outlined, size: 20),
    );
  }

  Widget _centerModeButton(double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () => widget.onModeChanged(InputMode.center),
      bgColor: Colors.white,
      isActive: widget.currentMode == InputMode.center,
      child: const Text(
        '123',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  // Number buttons (1-9)
  Widget _numberButton(int number, double width, double height) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () => widget.onNumberPressed(number),
      bgColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: const TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // Color buttons (1-9 mapped to colors)
  Widget _colorButton(
    int colorIndex,
    Color color,
    double width,
    double height,
  ) {
    return _baseButton(
      width: width,
      height: height,
      onPressed: () => widget.onColorPressed(colorIndex),
      bgColor: color.withOpacity(0.1),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}