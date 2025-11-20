// File path: lib/widgets/sudoku_grid.dart
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../models/sudoku_cell.dart';
import '../models/position.dart';
import '../models/variant_constraint.dart';
import '../utils/realm_theme.dart';

class SudokuGrid extends StatefulWidget {
  final GameController controller;
  final RealmTheme theme;

  const SudokuGrid({
    super.key,
    required this.controller,
    required this.theme,
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
            // Overlay: All constraints (rendered on top of grid)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ConstraintPainter(
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
    // 🔥 NEW: Clear hint on cell tap
    widget.controller.clearHint();
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

    // 🔥 NEW: Check if this is the hinted cell
    final isHintedCell = widget.controller.gameState.hintCell?.row == row &&
        widget.controller.gameState.hintCell?.col == col;

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      onPanStart: (details) => onCellDragStart(row, col),
      onPanUpdate: (details) => onCellDragUpdate(details),
      onPanEnd: (details) => onCellDragEnd(),
      child: Stack(
        children: [
          // Base container - background color
          Container(
            color: getCellBackgroundColor(cell, isHintedCell),
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
          // Overlay 2: Hint cell border (green highlight)
          if (isHintedCell)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFF4ADE80),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          // Overlay 3: Colored thick border (when same number and colored)
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
          // Overlay 4: Error border (if needed)
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
            child: _buildCellContent(cell, isHintedCell),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(SudokuCell cell, bool isHintedCell) {
    if (cell.number != null) {
      return buildMainNumber(cell);
    }

    // 🔥 NEW: Show hint number if cell is hinted, empty, and has a suggestion
    if (isHintedCell &&
        widget.controller.gameState.hintNumber != null &&
        cell.number == null) {
      return buildHintNumber(widget.controller.gameState.hintNumber!);
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

  // 🔥 NEW: Build hint number display
  Widget buildHintNumber(int number) {
    return Center(
      child: Text(
        number.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4ADE80).withOpacity(0.6), // Semi-transparent green
        ),
      ),
    );
  }

  Widget buildMainNumber(SudokuCell cell) {
    return Center(
      child: Text(
        cell.number.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: cell.isGiven
              ? widget.theme.textPrimary
              : widget.theme.textSecondary,
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
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.theme.textSecondary,
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
          color: widget.theme.textSecondary,
          fontWeight: FontWeight.w400,
          height: 1.0,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Border getCellBorder(SudokuCell cell, int row, int col) {
    if (cell.isSelected && cell.cellColor != null) {
      return Border.all(width: 4, color: cell.cellColor!);
    }

    if (cell.isHighlighted && cell.cellColor != null) {
      return Border.all(width: 4, color: cell.cellColor!);
    }

    return Border(
      top: BorderSide(
        width: row % 3 == 0 ? 2 : 0.5,
        color: widget.theme.borderColor,
      ),
      left: BorderSide(
        width: col % 3 == 0 ? 2 : 0.5,
        color: widget.theme.borderColor,
      ),
      right: BorderSide(
        width: col == 8 ? 2 : 0.5,
        color: widget.theme.borderColor,
      ),
      bottom: BorderSide(
        width: row == 8 ? 2 : 0.5,
        color: widget.theme.borderColor,
      ),
    );
  }

  // 🔥 UPDATED: Added isHintedCell parameter
  Color getCellBackgroundColor(SudokuCell cell, bool isHintedCell) {
    final selectedNumber = widget.controller.getSelectedNumber();

    Color color;

    // 🔥 NEW: Hinted cell gets green background
    if (isHintedCell) {
      color = Color(0xFF4ADE80).withOpacity(0.25); // Light green
    } else if (cell.isError) {
      color = Colors.red.shade200;
    } else if (cell.isSelected) {
      color = widget.theme.selectedColor;
    } else if (selectedNumber != null &&
        cell.number == selectedNumber &&
        cell.number != null) {
      color = widget.theme.sameNumberColor;
    } else if (cell.isHighlighted && cell.cellColor != null) {
      color = widget.theme.highlightedColor;
    } else if (cell.isHighlighted) {
      color = widget.theme.highlightedColor;
    } else if (cell.cellColor != null) {
      color = cell.cellColor!;
    } else {
      color = widget.theme.backgroundColor;
    }

    return color;
  }
}

/// Custom painter for rendering all constraint types
class ConstraintPainter extends CustomPainter {
  final List<VariantConstraint> constraints;

  ConstraintPainter({required this.constraints});

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 PAINT at ${DateTime.now()}');
    print('🎨 Canvas size: $size');
    print('🎨 Number of constraints: ${constraints.length}');

    final cellSize = size.width / 9;
    final dotRadius = cellSize * 0.12;

    print('🎨 Cell size: $cellSize, Dot radius: $dotRadius');

    Set<String> paintedConstraints = {};

    for (var constraint in constraints) {
      String constraintKey = '';
      if (constraint.type == ConstraintType.KROPKI_WHITE ||
          constraint.type == ConstraintType.KROPKI_BLACK ||
          constraint.type == ConstraintType.XV_X ||
          constraint.type == ConstraintType.XV_V ||
          constraint.type == ConstraintType.GERMAN_WHISPERS) {
        final minRow = constraint.row1 < constraint.row2
            ? constraint.row1
            : constraint.row2;
        final maxRow = constraint.row1 < constraint.row2
            ? constraint.row2
            : constraint.row1;
        final minCol = constraint.col1 < constraint.col2
            ? constraint.col1
            : constraint.col2;
        final maxCol = constraint.col1 < constraint.col2
            ? constraint.col2
            : constraint.col1;
        constraintKey =
            '${constraint.type}_${minRow}_${minCol}_${maxRow}_${maxCol}';

        if (paintedConstraints.contains(constraintKey)) {
          print('⭐️ Skipping duplicate: $constraintKey');
          continue;
        }
        paintedConstraints.add(constraintKey);
      }

      print('🔥 Constraint type: ${constraint.type}');
      print(
          '🔥 Constraint details: row1=${constraint.row1}, col1=${constraint.col1}, row2=${constraint.row2}, col2=${constraint.col2}');
      if (constraint.thermoCells != null) {
        print('🔥 Thermo cells: ${constraint.thermoCells!.length}');
      }
      if (constraint.sandwichSum != null) {
        print('🔥 Sandwich sum: ${constraint.sandwichSum}');
      }

      switch (constraint.type) {
        case ConstraintType.KROPKI_WHITE:
        case ConstraintType.KROPKI_BLACK:
          _paintKropkiDot(canvas, constraint, cellSize, dotRadius);
          break;
        case ConstraintType.XV_X:
        case ConstraintType.XV_V:
          _paintXV(canvas, constraint, cellSize);
          break;
        case ConstraintType.GERMAN_WHISPERS:
          _paintGermanWhispers(canvas, constraint, cellSize);
          break;
        case ConstraintType.THERMO:
          _paintThermo(canvas, constraint, cellSize);
          break;
        case ConstraintType.SANDWICH:
          _paintSandwich(canvas, constraint, cellSize);
          break;
      }
    }
  }

  void _paintKropkiDot(Canvas canvas, VariantConstraint constraint,
      double cellSize, double dotRadius) {
    final dotColor = constraint.type == ConstraintType.KROPKI_WHITE
        ? Colors.white
        : Colors.black;

    Offset dotCenter;

    if (constraint.orientation == 'horizontal') {
      final x = (constraint.col1 + 1) * cellSize;
      final y = constraint.row1 * cellSize + cellSize / 2;
      dotCenter = Offset(x, y);
      print(
          '🎨 H-dot: row=${constraint.row1}, cols ${constraint.col1}-${constraint.col2} → $dotCenter');
    } else {
      final x = constraint.col1 * cellSize + cellSize / 2;
      final y = (constraint.row1 + 1) * cellSize;
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

  void _paintXV(Canvas canvas, VariantConstraint constraint, double cellSize) {
    final isX = constraint.type == ConstraintType.XV_X;
    final text = isX ? 'X' : 'V';

    Offset center;
    if (constraint.orientation == 'horizontal') {
      final x = (constraint.col1 + 1) * cellSize;
      final y = constraint.row1 * cellSize + cellSize / 2;
      center = Offset(x, y);
    } else {
      final x = constraint.col1 * cellSize + cellSize / 2;
      final y = (constraint.row1 + 1) * cellSize;
      center = Offset(x, y);
    }

    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final lineEraserSize = cellSize * 0.25;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: lineEraserSize,
        height: lineEraserSize,
      ),
      Radius.circular(2),
    );
    canvas.drawRRect(bgRect, bgPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: cellSize * 0.35,
          fontWeight: FontWeight.bold,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    print('🎨 XV-${text}: ${constraint.orientation} at $center');
  }

  void _paintGermanWhispers(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    final paint = Paint()
      ..color = Color(0xFF22c55e)
      ..strokeWidth = cellSize * 0.15
      ..strokeCap = StrokeCap.round;

    Offset start, end;
    if (constraint.orientation == 'horizontal') {
      start = Offset(
        (constraint.col1 + 0.7) * cellSize,
        constraint.row1 * cellSize + cellSize / 2,
      );
      end = Offset(
        (constraint.col2 + 0.3) * cellSize,
        constraint.row2 * cellSize + cellSize / 2,
      );
    } else {
      start = Offset(
        constraint.col1 * cellSize + cellSize / 2,
        (constraint.row1 + 0.7) * cellSize,
      );
      end = Offset(
        constraint.col2 * cellSize + cellSize / 2,
        (constraint.row2 + 0.3) * cellSize,
      );
    }

    canvas.drawLine(start, end, paint);
    print('🎨 GermanWhispers: ${constraint.orientation} from $start to $end');
  }

  void _paintThermo(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    if (constraint.thermoCells == null || constraint.thermoCells!.isEmpty) {
      return;
    }

    final cells = constraint.thermoCells!;

    if (cells.length > 1) {
      final linePaint = Paint()
        ..color = Color(0xFFe5e7eb).withOpacity(0.9)
        ..strokeWidth = cellSize * 0.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < cells.length; i++) {
        final center = Offset(
          cells[i].col * cellSize + cellSize / 2,
          cells[i].row * cellSize + cellSize / 2,
        );
        if (i == 0) {
          path.moveTo(center.dx, center.dy);
        } else {
          path.lineTo(center.dx, center.dy);
        }
      }
      canvas.drawPath(path, linePaint);

      final pathBorderPaint = Paint()
        ..color = Color(0xFF9ca3af)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawPath(path, pathBorderPaint);
    }

    final bulbCenter = Offset(
      cells[0].col * cellSize + cellSize / 2,
      cells[0].row * cellSize + cellSize / 2,
    );

    final glowPaint = Paint()
      ..color = Color(0xFF9ca3af).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bulbCenter, cellSize * 0.42, glowPaint);

    final bulbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color(0xFFf3f4f6),
          Color(0xFFe5e7eb),
        ],
        stops: [0.3, 1.0],
      ).createShader(
          Rect.fromCircle(center: bulbCenter, radius: cellSize * 0.38))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bulbCenter, cellSize * 0.38, bulbPaint);

    final borderPaint = Paint()
      ..color = Color(0xFF6b7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(bulbCenter, cellSize * 0.38, borderPaint);

    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final shineOffset = Offset(
      bulbCenter.dx - cellSize * 0.12,
      bulbCenter.dy - cellSize * 0.12,
    );
    canvas.drawCircle(shineOffset, cellSize * 0.12, shinePaint);

    print(
        '🎨 Thermo: ${cells.length} cells from ${cells.first} to ${cells.last}');
  }

  void _paintSandwich(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    if (constraint.sandwichSum == null) return;

    final sum = constraint.sandwichSum!;
    Offset position;

    if (constraint.sandwichRow != null) {
      final row = constraint.sandwichRow!;
      final isLeft = constraint.col1 == -1;
      position = Offset(
        isLeft ? -cellSize * 0.5 : 9 * cellSize + cellSize * 0.5,
        row * cellSize + cellSize / 2,
      );
    } else {
      final col = constraint.sandwichCol!;
      final isTop = constraint.row1 == -1;
      position = Offset(
        col * cellSize + cellSize / 2,
        isTop ? -cellSize * 0.5 : 9 * cellSize + cellSize * 0.5,
      );
    }

    final radius = cellSize * 0.35;

    final shadowPaint = Paint()
      ..color = Color(0xFFf59e0b).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius + 3, shadowPaint);

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color(0xFFfde047),
          Color(0xFFfbbf24),
        ],
        stops: [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: position, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius, bgPaint);

    final borderPaint = Paint()
      ..color = Color(0xFFd97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(position, radius, borderPaint);

    final innerHighlight = Paint()
      ..color = Color(0xFFfef3c7).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(position.dx - radius * 0.2, position.dy - radius * 0.2),
      radius * 0.3,
      innerHighlight,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: sum.toString(),
        style: TextStyle(
          color: Color(0xFF78350f),
          fontSize: cellSize * 0.28,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.5),
              offset: Offset(0.5, 0.5),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );

    print('🎨 Sandwich: sum=$sum at $position');
  }

  @override
  bool shouldRepaint(ConstraintPainter oldDelegate) {
    return false;
  }
}
