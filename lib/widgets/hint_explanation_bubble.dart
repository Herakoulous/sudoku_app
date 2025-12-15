// File path: lib/widgets/hint_explanation_bubble.dart
import 'package:flutter/material.dart';
import '../utils/realm_theme.dart';

class HintExplanationBubble extends StatefulWidget {
  final String? explanation;
  final RealmTheme theme;
  final VoidCallback onClose;
  final String? hintType;

  const HintExplanationBubble({
    super.key,
    required this.explanation,
    required this.theme,
    required this.onClose,
    this.hintType,
  });

  @override
  State<HintExplanationBubble> createState() => _HintExplanationBubbleState();
}

class _HintExplanationBubbleState extends State<HintExplanationBubble> {
  int _currentParagraphIndex = 0;
  late List<String> _paragraphs;

  @override
  void initState() {
    super.initState();
    _parseParagraphs();
  }

  @override
  void didUpdateWidget(HintExplanationBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.explanation != widget.explanation) {
      _currentParagraphIndex = 0;
      _parseParagraphs();
    }
  }

  void _parseParagraphs() {
    if (widget.explanation == null) {
      _paragraphs = [];
      return;
    }

    // Split by double newlines first (paragraph breaks)
    final paragraphs = widget.explanation!.split('\n\n');
    _paragraphs = [];

    for (final para in paragraphs) {
      if (para.trim().isEmpty) continue;

      // Split very long paragraphs by single newlines
      final lines = para.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        // If still too long, split by sentences
        if (line.length > 150) {
          final sentences = line.split('. ');
          for (int i = 0; i < sentences.length; i++) {
            String sentence = sentences[i].trim();
            if (sentence.isEmpty) continue;
            if (i < sentences.length - 1 && !sentence.endsWith('.')) {
              sentence += '.';
            }
            _paragraphs.add(sentence);
          }
        } else {
          _paragraphs.add(line.trim());
        }
      }
    }

    if (_paragraphs.isEmpty && widget.explanation != null) {
      _paragraphs = [widget.explanation!];
    }
  }

  void _nextParagraph() {
    if (_currentParagraphIndex < _paragraphs.length - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
    }
  }

  void _previousParagraph() {
    if (_currentParagraphIndex > 0) {
      setState(() {
        _currentParagraphIndex--;
      });
    }
  }

  String _formatHintType(String? hintType) {
    if (hintType == null) return 'Hint';

    // Handle standard hints
    if (hintType.startsWith('HintType.')) {
      return hintType.replaceAll('HintType.', '').replaceAll('_', ' ');
    }

    // Handle Kropki hints
    if (hintType.contains('Kropki')) {
      return hintType.replaceAll('_', ' ');
    }

    // Clean up the hint type
    return hintType
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  Color _getDifficultyColor(String? hintType) {
    if (hintType == null) return widget.theme.primaryColor;

    // Beginner - Green
    if (hintType.contains('Naked Single') ||
        hintType.contains('Hidden Single') ||
        hintType.contains('Full House')) {
      return Colors.green;
    }

    // Easy - Blue
    if (hintType.contains('Locked Candidates') ||
        hintType.contains('Locked Pair') ||
        hintType.contains('Naked Pair') ||
        hintType.contains('Hidden Pair')) {
      return Colors.blue;
    }

    // Medium - Yellow
    if (hintType.contains('Triple') ||
        hintType.contains('X-Wing') ||
        hintType.contains('Skyscraper') ||
        hintType.contains('Kite') ||
        hintType.contains('Empty Rectangle')) {
      return Colors.amber;
    }

    // Hard - Orange
    if (hintType.contains('Swordfish') ||
        hintType.contains('XY-Wing') ||
        hintType.contains('XYZ-Wing') ||
        hintType.contains('W-Wing') ||
        hintType.contains('Uniqueness') ||
        hintType.contains('Rectangle') ||
        hintType.contains('Turbot Fish')) {
      return Colors.orange;
    }

    // Extreme - Red
    if (hintType.contains('Chain') ||
        hintType.contains('Loop') ||
        hintType.contains('AIC') ||
        hintType.contains('ALS') ||
        hintType.contains('Forcing') ||
        hintType.contains('Sue de Coq')) {
      return Colors.red;
    }

    return widget.theme.primaryColor;
  }

  String _getDifficultyEmoji(String? hintType) {
    if (hintType == null) return '💡';

    if (hintType.contains('Naked Single') ||
        hintType.contains('Hidden Single') ||
        hintType.contains('Full House')) {
      return '🟢';
    }

    if (hintType.contains('Locked Candidates') ||
        hintType.contains('Locked Pair') ||
        hintType.contains('Naked Pair') ||
        hintType.contains('Hidden Pair')) {
      return '🔵';
    }

    if (hintType.contains('Triple') ||
        hintType.contains('X-Wing') ||
        hintType.contains('Skyscraper') ||
        hintType.contains('Kite') ||
        hintType.contains('Empty Rectangle')) {
      return '🟡';
    }

    if (hintType.contains('Swordfish') ||
        hintType.contains('Wing') ||
        hintType.contains('Uniqueness') ||
        hintType.contains('Rectangle') ||
        hintType.contains('Turbot Fish')) {
      return '🟠';
    }

    if (hintType.contains('Chain') ||
        hintType.contains('Loop') ||
        hintType.contains('AIC') ||
        hintType.contains('ALS') ||
        hintType.contains('Forcing') ||
        hintType.contains('Sue de Coq')) {
      return '🔴';
    }

    return '💡';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.explanation == null || _paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentText = _paragraphs[_currentParagraphIndex];
    final totalParagraphs = _paragraphs.length;
    final hasMultipleParagraphs = totalParagraphs > 1;
    final difficultyColor = _getDifficultyColor(widget.hintType);
    final emoji = _getDifficultyEmoji(widget.hintType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: difficultyColor.withOpacity(0.1),
        border: Border.all(
          color: difficultyColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: difficultyColor.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '$emoji Hint',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: difficultyColor,
                      ),
                    ),
                    if (widget.hintType != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: difficultyColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: difficultyColor.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatHintType(widget.hintType),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: difficultyColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: difficultyColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Explanation text
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(
                currentText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),

          // Navigation
          if (hasMultipleParagraphs) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button
                GestureDetector(
                  onTap: _currentParagraphIndex > 0 ? _previousParagraph : null,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _currentParagraphIndex > 0
                          ? difficultyColor.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _currentParagraphIndex > 0
                            ? difficultyColor
                            : Colors.grey.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: 14,
                      color: _currentParagraphIndex > 0
                          ? difficultyColor
                          : Colors.grey,
                    ),
                  ),
                ),

                // Page indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: difficultyColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_currentParagraphIndex + 1}/$totalParagraphs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: difficultyColor,
                    ),
                  ),
                ),

                // Next button
                GestureDetector(
                  onTap: _currentParagraphIndex < totalParagraphs - 1
                      ? _nextParagraph
                      : null,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _currentParagraphIndex < totalParagraphs - 1
                          ? difficultyColor.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _currentParagraphIndex < totalParagraphs - 1
                            ? difficultyColor
                            : Colors.grey.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: _currentParagraphIndex < totalParagraphs - 1
                          ? difficultyColor
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
