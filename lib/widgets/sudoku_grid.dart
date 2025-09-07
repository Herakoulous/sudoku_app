// widgets/sudoku_grid.dart
import 'package:flutter/material.dart';
import '../models/sudoku_cell.dart';
import '../models/variants/variant_constraint.dart';
import 'sudoku/variant_overlays/kropki_overlay.dart';
import 'sudoku/variant_overlays/killer_overlay.dart';
import 'sudoku/variant_overlays/xv_overlay.dart';
import 'sudoku/variant_overlays/german_whispers_overlay.dart';
import 'sudoku/variant_overlays/thermometer_overlay.dart';
import 'sudoku/variant_overlays/sandwich_overlay.dart';

class SudokuGrid extends StatelessWidget {
  final List<List<SudokuCell>> grid;
  final int? selectedRow, selectedCol;
  final Set<String> relatedCells;
  final Set<String> selectedCells;
  final Set<String> sameNumberCells;
  final Function(int, int) onCellTapped;
  final Function(int, int) onCellDragStart;
  final Function(int, int) onCellDragUpdate;
  final VoidCallback onCellDragEnd;
  final List<VariantConstraint>? variantConstraints;

  const SudokuGrid({
    Key? key,
    required this.grid,
    required this.selectedRow,
    required this.selectedCol,
    required this.relatedCells,
    required this.selectedCells,
    required this.sameNumberCells,
    required this.onCellTapped,
    required this.onCellDragStart,
    required this.onCellDragUpdate,
    required this.onCellDragEnd,
    this.variantConstraints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSize = constraints.maxWidth;
        final cellSize = gridSize / 9; // Simplified cell size calculation

        return Container(
          width: gridSize,
          height: gridSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Beautiful gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF8FAFC),
                      ],
                    ),
                  ),
                ),
                
                // Grid lines background
                CustomPaint(
                  size: Size(gridSize, gridSize),
                  painter: _GridLinesPainter(),
                ),
                
                // Main grid with interactive cells
                RepaintBoundary(
                  child: SizedBox(
                    width: gridSize,
                    height: gridSize,
                    child: Stack(
                      children: List.generate(81, (index) {
                        final row = index ~/ 9;
                        final col = index % 9;
                        return Positioned(
                          left: col * cellSize,
                          top: row * cellSize,
                          width: cellSize,
                          height: cellSize,
                          child: _SudokuCell(
                            key: ValueKey('cell-$row-$col'),
                            row: row,
                            col: col,
                            cell: grid[row][col],
                            cellSize: cellSize,
                            isSelected: selectedRow == row && selectedCol == col,
                            isRelated: relatedCells.contains('$row-$col'),
                            isMultiSelected: selectedCells.contains('$row-$col'),
                            isSameNumber: sameNumberCells.contains('$row-$col'),
                            onTap: () => onCellTapped(row, col),
                            onDragStart: () => onCellDragStart(row, col),
                            onDragUpdate: () => onCellDragUpdate(row, col),
                            onDragEnd: onCellDragEnd,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                
                // Variant overlays with RepaintBoundary - positioned to not block touches
                if (variantConstraints != null)
                  RepaintBoundary(
                    child: IgnorePointer(
                      child: Stack(
                        children: _buildVariantOverlays(gridSize),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildVariantOverlays(double gridSize) {
    return variantConstraints!.map((constraint) {
      switch (constraint.type) {
        case 'kropki':
          return KropkiOverlay(
            constraints: [constraint as KropkiConstraint],
            gridSize: gridSize,
          );
        case 'killer':
          return KillerOverlay(
            constraints: [constraint as KillerConstraint],
            gridSize: gridSize,
          );
        case 'xv':
          return XVOverlay(
            constraints: [constraint as XVConstraint],
            gridSize: gridSize,
          );
        case 'german_whispers':
          return GermanWhispersOverlay(
            constraints: [constraint as GermanWhispersConstraint],
            gridSize: gridSize,
          );
        case 'thermometer':
          return ThermometerOverlay(
            constraints: [constraint as ThermometerConstraint],
            gridSize: gridSize,
          );
        case 'sandwich':
          return SandwichOverlay(
            constraints: [constraint as SandwichConstraint],
            gridSize: gridSize,
          );
        default:
          return const SizedBox.shrink();
      }
    }).toList();
  }
}

/// Custom painter for grid lines
class _GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final thinPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.0;
      
    final thickPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 3.0;

    final cellSize = size.width / 9;

    // Draw vertical lines
    for (int i = 0; i <= 9; i++) {
      final x = i * cellSize;
      final paint = (i % 3 == 0) ? thickPaint : thinPaint;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (int i = 0; i <= 9; i++) {
      final y = i * cellSize;
      final paint = (i % 3 == 0) ? thickPaint : thinPaint;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Optimized individual cell widget without borders
class _SudokuCell extends StatelessWidget {
  final int row, col;
  final SudokuCell cell;
  final double cellSize;
  final bool isSelected, isRelated, isMultiSelected, isSameNumber;
  final VoidCallback onTap, onDragStart, onDragUpdate, onDragEnd;

  const _SudokuCell({
    Key? key,
    required this.row,
    required this.col,
    required this.cell,
    required this.cellSize,
    required this.isSelected,
    required this.isRelated,
    required this.isMultiSelected,
    required this.isSameNumber,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (_) => onDragUpdate(),
        onPanEnd: (_) => onDragEnd(),
        behavior: HitTestBehavior.opaque, // Ensures the entire area is tappable
        child: Container(
          width: cellSize,
          height: cellSize,
          color: _getCellColor(), // Removed decoration, using simple color
          child: _buildCellContent(),
        ),
      ),
    );
  }

  Color _getCellColor() {
    if (isSelected) {
      return const Color(0xFF6366F1).withOpacity(0.3);
    }
    if (isMultiSelected) {
      return const Color(0xFF8B5CF6).withOpacity(0.2);
    }
    if (isRelated) {
      return const Color(0xFF06B6D4).withOpacity(0.1);
    }
    if (isSameNumber) {
      return const Color(0xFF10B981).withOpacity(0.2);
    }
    if (cell.hasConflict) {
      return const Color(0xFFEF4444).withOpacity(0.3);
    }
    if (cell.colorHighlight > 0) {
      return _getHighlightColor(cell.colorHighlight);
    }
    return Colors.transparent;
  }

  Color _getHighlightColor(int colorIndex) {
    const colors = [
      Color(0xFFEF4444), // Red
      Color(0xFF6366F1), // Indigo
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFF8B5CF6), // Purple
      Color(0xFF06B6D4), // Cyan
    ];
    return colors[colorIndex % colors.length].withOpacity(0.2);
  }

  Widget _buildCellContent() {
    if (cell.digit != null) {
      return Center(
        child: Text(
          '${cell.digit}',
          style: TextStyle(
            fontSize: cellSize * 0.4, // Responsive font size
            fontWeight: cell.isGiven ? FontWeight.bold : FontWeight.w600,
            color: cell.isGiven 
                ? const Color(0xFF1E293B) 
                : const Color(0xFF6366F1),
            shadows: cell.isGiven ? null : [
              Shadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    if (cell.cornerMarks.isNotEmpty || cell.centerMarks.isNotEmpty) {
      return Stack(
        children: [
          // Corner marks
          if (cell.cornerMarks.isNotEmpty)
            Positioned(
              top: 2,
              left: 2,
              child: _buildMarks(cell.cornerMarks, cellSize * 0.12, true),
            ),
          // Center marks
          if (cell.centerMarks.isNotEmpty)
            Center(
              child: _buildMarks(cell.centerMarks, cellSize * 0.18, false),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMarks(Set<int> marks, double fontSize, bool isCorner) {
    final sortedMarks = marks.toList()..sort();
    final rows = (sortedMarks.length / 3).ceil();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (rowIndex) {
        final startIndex = rowIndex * 3;
        final endIndex = (startIndex + 3).clamp(0, sortedMarks.length);
        final rowMarks = sortedMarks.sublist(startIndex, endIndex);
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: rowMarks.map((mark) => 
            SizedBox(
              width: fontSize * 1.2,
              height: fontSize * 1.2,
              child: Center(
                child: Text(
                  '$mark',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ).toList(),
        );
      }),
    );
  }
}