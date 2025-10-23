// File path: lib/widgets/rules_popup.dart
import 'package:flutter/material.dart';

class RulesPopup extends StatelessWidget {
  const RulesPopup({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RulesPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Sudoku Rules',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: buildRulesContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget buildRulesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRuleSection(
          'Objective:',
          'Fill the 9×9 grid with numbers 1 through 9.',
        ),
        const SizedBox(height: 16),
        _buildRuleSection(
          'Rules:',
          '• Each row must contain the numbers 1-9 exactly once\n'
              '• Each column must contain the numbers 1-9 exactly once\n'
              '• Each 3×3 box must contain the numbers 1-9 exactly once',
        ),
        const SizedBox(height: 16),
        _buildRuleSection(
          'How to Play:',
          '• Tap a cell to select it\n'
              '• Use the number buttons to enter numbers\n'
              '• Switch between modes:\n'
              '  - Normal: Enter main numbers\n'
              '  - Side: Add small corner notes\n'
              '  - Center: Add center notes\n'
              '  - Color: Color cells for organization',
        ),
        const SizedBox(height: 16),
        _buildRuleSection(
          'Tips:',
          '• Use notes to track possible numbers\n'
              '• Invalid numbers will show in red\n'
              '• Use colors to group related cells\n'
              '• Undo/Redo buttons help fix mistakes',
        ),
      ],
    );
  }

  Widget _buildRuleSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
