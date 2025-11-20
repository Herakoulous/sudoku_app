// File path: lib/widgets/hint_explanation_bubble.dart
import 'package:flutter/material.dart';
import '../utils/realm_theme.dart';

class HintExplanationBubble extends StatefulWidget {
  final String? explanation;
  final RealmTheme theme;
  final VoidCallback onClose;

  const HintExplanationBubble({
    super.key,
    required this.explanation,
    required this.theme,
    required this.onClose,
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
    // Split explanation by newlines or by sentences if text is very long
    if (widget.explanation == null) {
      _paragraphs = [];
      return;
    }

    // Split by explicit newlines first
    final lines = widget.explanation!.split('\n');
    _paragraphs = [];

    for (final line in lines) {
      if (line.isEmpty) continue;

      // If a line is too long (>120 chars), split by sentences
      if (line.length > 120) {
        final sentences = line.split('. ');
        for (int i = 0; i < sentences.length; i++) {
          String sentence = sentences[i];
          if (i < sentences.length - 1 && !sentence.endsWith('.')) {
            sentence += '.';
          }
          _paragraphs.add(sentence);
        }
      } else {
        _paragraphs.add(line);
      }
    }

    // If still no paragraphs, treat the whole thing as one
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

  @override
  Widget build(BuildContext context) {
    if (widget.explanation == null || _paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentText = _paragraphs[_currentParagraphIndex];
    final totalParagraphs = _paragraphs.length;
    final hasMultipleParagraphs = totalParagraphs > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.theme.primaryColor.withOpacity(0.15),
        border: Border.all(
          color: widget.theme.primaryColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: widget.theme.primaryColor.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💡 Hint',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.primaryColor,
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: widget.theme.primaryColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Explanation text - grows to fit content
          SingleChildScrollView(
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

          // Navigation and indicator
          if (hasMultipleParagraphs) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left arrow button
                GestureDetector(
                  onTap: _currentParagraphIndex > 0 ? _previousParagraph : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _currentParagraphIndex > 0
                          ? widget.theme.primaryColor.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _currentParagraphIndex > 0
                            ? widget.theme.primaryColor
                            : Colors.grey.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: 16,
                      color: _currentParagraphIndex > 0
                          ? widget.theme.primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),

                // Paragraph indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.theme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.theme.primaryColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_currentParagraphIndex + 1}/$totalParagraphs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.primaryColor,
                    ),
                  ),
                ),

                // Right arrow button
                GestureDetector(
                  onTap: _currentParagraphIndex < totalParagraphs - 1
                      ? _nextParagraph
                      : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _currentParagraphIndex < totalParagraphs - 1
                          ? widget.theme.primaryColor.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _currentParagraphIndex < totalParagraphs - 1
                            ? widget.theme.primaryColor
                            : Colors.grey.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: _currentParagraphIndex < totalParagraphs - 1
                          ? widget.theme.primaryColor
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
