// File path: lib/widgets/sudoku_grid.dart
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../models/sudoku_cell.dart';
import '../models/position.dart';
import '../models/variant_constraint.dart';

class SudokuGrid extends StatefulWidget {
  final GameController controller;

  const SudokuGrid({
    super.key,
    required this.controller,
  });

  @override
  State<SudokuGrid> createState() => _SudokuGridState();
}

class _SudokuGridState extends State<SudokuGrid> {
  bool _isDragging = false;
  Set<Position> _draggedCells = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    print('===== _onGameStateChanged called at ${DateTime.now()} =====');
    print('Stack trace: ${StackTrace.current}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print('===== SudokuGrid BUILD at ${DateTime.now()} =====');
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 50),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            // Grid of cells
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
              ),
              itemCount: 81,
              itemBuilder: (context, index) {
                final row = index ~/ 9;
                final col = index % 9;
                final cell = widget.controller.gameState.grid[row][col];
                return buildCell(row, col, cell);
              },
            ),
            // Overlay: Kropki dots (rendered on top of grid)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KropkiDotsPainter(
                    constraints: widget.controller.gameState.constraints,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onCellTap(int row, int col) {
    if (_draggedCells.length > 1) {
      return;
    }
    widget.controller.handleCellTap(row, col);
  }

  void onCellDragStart(int row, int col) {
    print('🖊️ Drag started at ($row, $col)');
    setState(() {
      _isDragging = true;
      _draggedCells.clear();
    });

    final pos = Position(row, col);
    _draggedCells.add(pos);

    widget.controller.gameState.selectedCells.clear();
    widget.controller.gameState.selectedCells.add(pos);

    widget.controller.updateHighlights();
  }

  void onCellDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);

    final adjustedY = localPosition.dy - 50;
    final cellSize = (box.size.width - 32) / 9;

    final col = ((localPosition.dx - 16) / cellSize).floor().clamp(0, 8);
    final row = (adjustedY / cellSize).floor().clamp(0, 8);

    final pos = Position(row, col);

    if (!_draggedCells.contains(pos)) {
      print('🖊️ Dragged to ($row, $col)');
      setState(() {
        _draggedCells.add(pos);
      });

      widget.controller.gameState.selectedCells.clear();
      widget.controller.gameState.selectedCells.addAll(_draggedCells);

      widget.controller.updateHighlights();
    }
  }

  void onCellDragEnd() {
    print('🖊️ Drag ended - ${_draggedCells.length} cells selected');

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isDragging = false;
          _draggedCells.clear();
        });
      }
    });
  }

  Widget buildCell(int row, int col, SudokuCell cell) {
    final selectedNumber = widget.controller.getSelectedNumber();
    final isSameNumberAndColored = selectedNumber != null &&
        cell.number == selectedNumber &&
        cell.number != null &&
        cell.cellColor != null;

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      onPanStart: (details) => onCellDragStart(row, col),
      onPanUpdate: (details) => onCellDragUpdate(details),
      onPanEnd: (details) => onCellDragEnd(),
      child: Stack(
        children: [
          // Base container - NO BORDER, just background color
          Container(
            color: getCellBackgroundColor(cell),
          ),
          // Overlay 1: Normal grid borders
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: getCellBorder(cell, row, col),
                ),
              ),
            ),
          ),
          // Overlay 2: Colored thick border (when same number and colored)
          if (isSameNumberAndColored)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: cell.cellColor!, width: 3),
                  ),
                ),
              ),
            ),
          // Overlay 3: Error border (if needed)
          if (cell.isError)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ),
          // Content ON TOP of all borders
          Positioned.fill(
            child: _buildCellContent(cell),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(SudokuCell cell) {
    if (cell.number != null) {
      return buildMainNumber(cell);
    }

    final hasSideNotes = cell.sideNotes.isNotEmpty;
    final hasCenterNotes = cell.centerNotes.isNotEmpty;

    if (hasSideNotes && hasCenterNotes) {
      return Stack(
        children: [
          buildSideNotes(cell),
          buildCenterNotes(cell),
        ],
      );
    } else if (hasSideNotes) {
      return buildSideNotes(cell);
    } else if (hasCenterNotes) {
      return buildCenterNotes(cell);
    }

    return const SizedBox.expand();
  }

  Widget buildMainNumber(SudokuCell cell) {
    return Center(
      child: Text(
        cell.number.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: cell.isGiven
              ? Colors.black
              : const Color.fromARGB(255, 0, 38, 70),
        ),
      ),
    );
  }

  Widget buildSideNotes(SudokuCell cell) {
    final notes = cell.sortedSideNotes.toList();

    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalNotes = notes.length;
    final topCount = (totalNotes + 1) ~/ 2;
    final bottomCount = totalNotes - topCount;

    final topNotes = notes.sublist(0, topCount);
    final bottomNotes = bottomCount > 0 ? notes.sublist(topCount) : <int>[];

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: topNotes.map((number) {
                return Text(
                  number.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(
            height: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bottomNotes.map((number) {
                return Text(
                  number.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCenterNotes(SudokuCell cell) {
    final notes = cell.sortedCenterNotes.toList();

    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    double fontSize;
    if (notes.length <= 4) {
      fontSize = 13;
    } else if (notes.length <= 5) {
      fontSize = 12;
    } else if (notes.length <= 6) {
      fontSize = 9;
    } else if (notes.length <= 7) {
      fontSize = 8;
    } else if (notes.length <= 8) {
      fontSize = 7;
    } else {
      fontSize = 6;
    }

    return Center(
      child: Text(
        notes.join(''),
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black,
          fontWeight: FontWeight.w400,
          height: 1.0,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Border getCellBorder(SudokuCell cell, int row, int col) {
    if (cell.isSelected && cell.cellColor != null) {
      return Border.all(
        width: 4,
        color: cell.cellColor!,
      );
    }

    if (cell.isHighlighted && cell.cellColor != null) {
      return Border.all(
        width: 4,
        color: cell.cellColor!,
      );
    }

    return Border(
      top: BorderSide(
        width: row % 3 == 0 ? 2 : 0.5,
        color: Colors.black,
      ),
      left: BorderSide(
        width: col % 3 == 0 ? 2 : 0.5,
        color: Colors.black,
      ),
      right: BorderSide(
        width: col == 8 ? 2 : 0.5,
        color: Colors.black,
      ),
      bottom: BorderSide(
        width: row == 8 ? 2 : 0.5,
        color: Colors.black,
      ),
    );
  }

  Color getCellBackgroundColor(SudokuCell cell) {
    final selectedNumber = widget.controller.getSelectedNumber();

    Color color;

    if (cell.isError) {
      color = Colors.red.shade200;
    } else if (cell.isSelected) {
      color = Colors.blue.shade600;
    } else if (selectedNumber != null &&
        cell.number == selectedNumber &&
        cell.number != null) {
      color = Colors.blue.shade200;
    } else if (cell.isHighlighted && cell.cellColor != null) {
      color = Colors.blue.shade100;
    } else if (cell.isHighlighted) {
      color = Colors.blue.shade100;
    } else if (cell.cellColor != null) {
      color = cell.cellColor!;
    } else {
      color = Colors.white;
    }

    return color;
  }
}

/// Custom painter for rendering Kropki dots between cells
class KropkiDotsPainter extends CustomPainter {
  final List<VariantConstraint> constraints;

  KropkiDotsPainter({required this.constraints});

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 PAINT at ${DateTime.now()}');
    print('Stack trace:\n${StackTrace.current}');
    print('🎨 Canvas size: $size');
    print('🎨 Number of constraints: ${constraints.length}');

    final cellSize =
        size.width / 9; // This is correct - canvas is already the grid size
    final dotRadius = cellSize * 0.12;

    print('🎨 Cell size: $cellSize, Dot radius: $dotRadius');

    for (var constraint in constraints) {
      if (constraint.type != ConstraintType.KROPKI_WHITE &&
          constraint.type != ConstraintType.KROPKI_BLACK) {
        continue;
      }

      final dotColor = constraint.type == ConstraintType.KROPKI_WHITE
          ? Colors.white
          : Colors.black;

      Offset dotCenter;

      if (constraint.orientation == 'horizontal') {
        // Dot between col1 and col2 at row1
        // Position: right edge of col1 cell = (col1 + 1) * cellSize
        final x = (constraint.col1 + 1) * cellSize; // 🔥 FIX
        final y = constraint.row1 * cellSize + cellSize / 2;
        dotCenter = Offset(x, y);
        print(
            '🎨 H-dot: row=${constraint.row1}, cols ${constraint.col1}-${constraint.col2} → $dotCenter');
      } else {
        // Dot between row1 and row2 at col1
        // Position: bottom edge of row1 cell = (row1 + 1) * cellSize
        final x = constraint.col1 * cellSize + cellSize / 2;
        final y = (constraint.row1 + 1) * cellSize; // 🔥 FIX
        dotCenter = Offset(x, y);
        print(
            '🎨 V-dot: col=${constraint.col1}, rows ${constraint.row1}-${constraint.row2} → $dotCenter');
      }

      final paint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;

      if (constraint.type == ConstraintType.KROPKI_WHITE) {
        final borderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(dotCenter, dotRadius, borderPaint);
      }

      canvas.drawCircle(dotCenter, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(KropkiDotsPainter oldDelegate) {
    return false;
  }
}
