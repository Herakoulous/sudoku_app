import 'package:flutter/material.dart';
import '../models/variant_constraint.dart';
import '../utils/realm_theme.dart';

class RulesPopup extends StatelessWidget {
  final List<ConstraintType> constraintTypes;
  final RealmTheme theme;
  final VoidCallback onClose;
  final VoidCallback? onGetHint; // ← ADD THIS LINE

  const RulesPopup({
    Key? key,
    required this.constraintTypes,
    required this.theme,
    required this.onClose,
    this.onGetHint, // ← ADD THIS LINE
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get unique constraint types (no duplicates)
    final uniqueTypes = constraintTypes.toSet().toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.primaryColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            _buildHeader(context),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Sudoku rules (always shown)
                    _buildBasicRules(),

                    // Variant-specific rules (if any)
                    if (uniqueTypes.isNotEmpty) ...[
                      SizedBox(height: 24),
                      _buildVariantRules(uniqueTypes),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // Hint button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        if (onGetHint != null) {
                          onGetHint!(); // Trigger hint
                        }
                      },
                      icon: Icon(Icons.lightbulb_outline, size: 24),
                      label: Text(
                        'Get a Hint',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Got it button (secondary)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(
                          color: theme.primaryColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Got it!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.help_outline,
            color: theme.primaryColor,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Puzzle Rules',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ),
          // Close button
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close),
            color: theme.accentColor,
            iconSize: 28,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Classic Sudoku Rules',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: 12),
        _buildRuleItem(
          '📍',
          'Fill the 9×9 grid with numbers 1-9',
          'Each row, column, and 3×3 box must contain each number exactly once.',
        ),
      ],
    );
  }

  Widget _buildVariantRules(List<ConstraintType> types) {
    // 🔥 NEW: Group related constraint types
    final uniqueRuleTypes = _getUniqueRuleTypes(types);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Rules',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: 16),
        ...uniqueRuleTypes.map((type) => _buildConstraintRule(type)).toList(),
      ],
    );
  }

// 🔥 ADD THIS METHOD
  List<ConstraintType> _getUniqueRuleTypes(List<ConstraintType> types) {
    Set<ConstraintType> uniqueTypes = {};

    for (var type in types) {
      // Group Kropki types together
      if (type == ConstraintType.KROPKI_WHITE ||
          type == ConstraintType.KROPKI_BLACK) {
        uniqueTypes
            .add(ConstraintType.KROPKI_WHITE); // Use WHITE as representative
      }
      // Group XV types together
      else if (type == ConstraintType.XV_X || type == ConstraintType.XV_V) {
        uniqueTypes.add(ConstraintType.XV_X); // Use X as representative
      }
      // Other types stay as-is
      else {
        uniqueTypes.add(type);
      }
    }

    return uniqueTypes.toList();
  }

  Widget _buildConstraintRule(ConstraintType type) {
    String title;
    String emoji;
    String description;
    Widget? visual;

    switch (type) {
      case ConstraintType.KROPKI_WHITE:
      case ConstraintType.KROPKI_BLACK:
        title = 'Kropki Dots';
        emoji = '⚪⚫';
        description =
            'White dot: Adjacent cells differ by 1 (consecutive numbers)\n'
            'Black dot: Adjacent cells are in 2:1 ratio (one is double the other)';
        visual = _buildKropkiVisual();
        break;

      case ConstraintType.THERMO:
        title = 'Thermometers';
        emoji = '🌡️';
        description =
            'Numbers must strictly increase from the bulb (circle) to the tip.\n'
            'Each cell along the thermometer must be greater than the previous cell.';
        visual = _buildThermoVisual();
        break;

      case ConstraintType.XV_X:
      case ConstraintType.XV_V:
        title = 'XV Constraints';
        emoji = 'Ⅹ Ⅴ';
        description = 'X: Adjacent cells sum to 10\n'
            'V: Adjacent cells sum to 5';
        visual = _buildXVVisual();
        break;

      case ConstraintType.GERMAN_WHISPERS:
        title = 'German Whispers';
        emoji = '💚';
        description =
            'Adjacent cells connected by a green line must differ by at least 5.';
        visual = _buildGermanWhispersVisual();
        break;

      case ConstraintType.SANDWICH:
        title = 'Sandwich Sums';
        emoji = '🥪';
        description =
            'The number outside the grid shows the sum of digits between 1 and 9 in that row/column.';
        visual = _buildSandwichVisual();
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          ...[
            SizedBox(height: 12),
            visual,
          ],
        ],
      ),
    );
  }

  Widget _buildRuleItem(String emoji, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Visual examples for constraints
  Widget _buildKropkiVisual() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniCell('3'),
          SizedBox(width: 4),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
          SizedBox(width: 4),
          _buildMiniCell('4'),
          SizedBox(width: 20),
          _buildMiniCell('2'),
          SizedBox(width: 4),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          _buildMiniCell('4'),
        ],
      ),
    );
  }

  Widget _buildThermoVisual() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(0xFFe5e7eb),
              shape: BoxShape.circle,
              border: Border.all(color: Color(0xFF6b7280), width: 2),
            ),
            child: Center(
              child: Text(
                '2',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Container(
            width: 20,
            height: 3,
            color: Color(0xFFe5e7eb),
          ),
          _buildMiniCell('5'),
          Container(
            width: 20,
            height: 3,
            color: Color(0xFFe5e7eb),
          ),
          _buildMiniCell('7'),
        ],
      ),
    );
  }

  Widget _buildXVVisual() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniCell('3'),
          SizedBox(width: 4),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'X',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          _buildMiniCell('7'),
          SizedBox(width: 20),
          _buildMiniCell('2'),
          SizedBox(width: 4),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'V',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          _buildMiniCell('3'),
        ],
      ),
    );
  }

  Widget _buildGermanWhispersVisual() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniCell('1'),
          Container(
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFF22c55e),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildMiniCell('7'),
        ],
      ),
    );
  }

  Widget _buildSandwichVisual() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(0xFFfbbf24),
              shape: BoxShape.circle,
              border: Border.all(color: Color(0xFFd97706), width: 2),
            ),
            child: Center(
              child: Text(
                '15',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF78350f),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          _buildMiniCell('1'),
          _buildMiniCell('5'),
          _buildMiniCell('6'),
          _buildMiniCell('4'),
          _buildMiniCell('9'),
          SizedBox(width: 8),
          Text(
            '5+6+4=15',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCell(String number) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // Static method to show the popup
  static void show(BuildContext context, List<ConstraintType> constraintTypes,
      RealmTheme theme, VoidCallback onClose,
      {VoidCallback? onGetHint} // Add this parameter
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RulesPopup(
        constraintTypes: constraintTypes,
        theme: theme,
        onClose: () {
          Navigator.of(context).pop();
          onClose();
        },
        onGetHint: onGetHint, // Pass it through
      ),
    );
  }
}
