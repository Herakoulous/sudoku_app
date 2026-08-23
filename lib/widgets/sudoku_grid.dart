// File path: lib/widgets/sudoku_grid.dart
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../models/sudoku_cell.dart';
import '../models/position.dart';
import '../models/variant_constraint.dart';
import '../models/hint_lesson.dart';
import '../utils/realm_theme.dart';
import 'hint_overlay_painter.dart';

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

class _SudokuGridState extends State<SudokuGrid>
    with TickerProviderStateMixin {
  bool _isDragging = false;
  Set<Position> _draggedCells = {};

  /// Plays once per hint stage, so links draw themselves and marks fade in
  /// rather than snapping.
  late final AnimationController _stageIn;

  /// Drives the breathing ring on emphasised cells. Only runs while a hint is on
  /// screen — a permanently repeating controller would schedule a frame forever
  /// and drain battery during ordinary play.
  late final AnimationController _pulse;

  HintStage? _lastStage;

  @override
  void initState() {
    super.initState();

    // Created here rather than as lazy `late` initialisers: a grid disposed
    // before any hint appeared would otherwise construct its controllers inside
    // dispose(), where the TickerMode ancestor lookup is already invalid.
    _stageIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    widget.controller.addListener(_onGameStateChanged);
    _syncStageAnimation();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameStateChanged);
    _stageIn.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Restarts the entrance animation whenever the visible stage changes.
  void _syncStageAnimation() {
    final stage = widget.controller.gameState.activeStage;
    if (identical(stage, _lastStage)) return;

    _lastStage = stage;
    if (stage == null) {
      _stageIn.value = 0;
      _pulse.stop();
    } else {
      _stageIn.forward(from: 0);
      if (!_pulse.isAnimating) _pulse.repeat();
    }
  }

  void _onGameStateChanged() {
    _syncStageAnimation();
    if (mounted) setState(() {});
  }

  /// Identifies the 9x9 board itself, so pointer positions can be mapped to
  /// cells from the board's own geometry instead of from hardcoded padding.
  final GlobalKey _boardKey = GlobalKey();

  /// Sandwich clues live outside the board, so the grid has to reserve room for
  /// them. Only sandwich puzzles pay for the gutter.
  List<VariantConstraint> get _sandwichClues => widget
      .controller.gameState.constraints
      .where((c) =>
          c.type == ConstraintType.SANDWICH && c.sandwichSum != null)
      .toList();

  @override
  Widget build(BuildContext context) {
    final clues = _sandwichClues;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 50),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Row clues sit to the left of the board and column clues above it.
          final gutter =
              clues.isEmpty ? 0.0 : (constraints.maxWidth * 0.09).clamp(22.0, 34.0);
          final boardSize = constraints.maxWidth - gutter;
          final cellSize = boardSize / 9;

          return SizedBox(
            width: constraints.maxWidth,
            height: boardSize + gutter,
            child: Stack(
              children: [
                for (final clue in clues)
                  _positionClue(clue, gutter, cellSize),
                Positioned(
                  left: gutter,
                  top: gutter,
                  width: boardSize,
                  height: boardSize,
                  child: _buildBoard(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoard() {
    final stage = widget.controller.gameState.activeStage;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCells(),
        if (stage != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_stageIn, _pulse]),
                builder: (context, _) => CustomPaint(
                  painter: HintOverlayPainter(
                    stage: stage,
                    progress: _stageIn.value,
                    pulse: _pulse.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCells() {
    return GridView.builder(
      key: _boardKey,
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
    );
  }

  Widget _positionClue(
      VariantConstraint clue, double gutter, double cellSize) {
    final isRowClue = clue.sandwichRow != null;

    return Positioned(
      left: isRowClue ? 0 : gutter + clue.sandwichCol! * cellSize,
      top: isRowClue ? gutter + clue.sandwichRow! * cellSize : 0,
      width: isRowClue ? gutter : cellSize,
      height: isRowClue ? cellSize : gutter,
      child: SandwichClueLabel(
        sum: clue.sandwichSum!,
        theme: widget.theme,
      ),
    );
  }

  /// Double taps are detected by hand rather than with GestureDetector's
  /// onDoubleTap. Declaring onDoubleTap makes every *single* tap wait out the
  /// double-tap timeout before firing, and cell selection is the most frequent
  /// action in the game — a 300ms lag on it is far worse than the feature is
  /// worth. Tracking tap times ourselves keeps selection instant.
  Position? _lastTapCell;
  DateTime? _lastTapTime;

  static const Duration _doubleTapWindow = Duration(milliseconds: 320);

  void onCellTap(int row, int col) {
    if (_draggedCells.length > 1) {
      return;
    }

    final pos = Position(row, col);
    final now = DateTime.now();

    final isDoubleTap = _lastTapCell == pos &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow;

    _lastTapCell = pos;
    _lastTapTime = now;

    // A lesson is dismissed explicitly, not by touching the board: the player
    // needs to be able to tap around and look at cells while reading it.
    if (widget.controller.gameState.activeLesson == null) {
      widget.controller.clearHint();
    }
    widget.controller.handleCellTap(row, col);

    if (isDoubleTap) {
      // Reset, so a third tap does not read as another double tap.
      _lastTapCell = null;
      _lastTapTime = null;

      // The second tap toggled this cell out of the selection. Put it back so
      // the number we are about to place stays selected and highlighted. Adding
      // without clearing keeps any multi-selection intact.
      widget.controller.gameState.selectedCells.add(pos);

      widget.controller.promoteSingleNote(row, col);
    }
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

    // Map the pointer through the board's own render box. The previous version
    // subtracted the padding by hand (16 left, 50 top), which silently breaks
    // the moment the layout changes — as it does for sandwich puzzles, where
    // the board is inset by a clue gutter.
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    final cellSize = box.size.width / 9;
    if (cellSize <= 0) return;

    final col = (local.dx / cellSize).floor().clamp(0, 8);
    final row = (local.dy / cellSize).floor().clamp(0, 8);

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

    // 🔥 FIX: Only check hint if hintCell is not null
    final hintCell = widget.controller.gameState.hintCell;
    final isHintedCell =
        hintCell != null && hintCell.row == row && hintCell.col == col;

    // 🔥 FIX: Only check highlights if the sets are not null
    final hintHighlightRows = widget.controller.gameState.hintHighlightRows;
    final hintHighlightColumns =
        widget.controller.gameState.hintHighlightColumns;
    final hintHighlightCells = widget.controller.gameState.hintHighlightCells;
    final hintHighlightNumbers =
        widget.controller.gameState.hintHighlightNumbers;

    final isRowHighlighted =
        hintHighlightRows?.contains(Position(row, col)) ?? false;
    final isColHighlighted =
        hintHighlightColumns?.contains(Position(row, col)) ?? false;
    final isCellHighlighted =
        hintHighlightCells?.contains(Position(row, col)) ?? false;

    // 🔥 FIX: Clean null-safe number highlighting
    bool isNumberHighlighted = false;

    if (!isHintedCell &&
        cell.number != null &&
        hintHighlightNumbers != null &&
        hintCell != null) {
      // Only highlight numbers that are in the SAME REGION as the hinted cell
      // AND are part of the restricting numbers
      final isInSameRow = row == hintCell.row;
      final isInSameCol = col == hintCell.col;
      final isInSameBox =
          (row ~/ 3 == hintCell.row ~/ 3) && (col ~/ 3 == hintCell.col ~/ 3);

      final isInSameRegion = isInSameRow || isInSameCol || isInSameBox;

      isNumberHighlighted =
          isInSameRegion && hintHighlightNumbers.contains(cell.number);
    }

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      onPanStart: (details) => onCellDragStart(row, col),
      onPanUpdate: (details) => onCellDragUpdate(details),
      onPanEnd: (details) => onCellDragEnd(),
      child: Stack(
        children: [
          // Base container - background color
          Container(
            color: getCellBackgroundColor(cell, isHintedCell, isRowHighlighted,
                isColHighlighted, isCellHighlighted, isNumberHighlighted),
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
          // Overlay 2: Constraints layer (UNDER numbers, OVER backgrounds)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: CellConstraintPainter(
                  constraints: widget.controller.gameState.constraints,
                  row: row,
                  col: col,
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
            child: _buildCellContent(cell, isHintedCell, isNumberHighlighted),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(
      SudokuCell cell, bool isHintedCell, bool isNumberHighlighted) {
    if (cell.number != null) {
      return buildMainNumber(cell, isNumberHighlighted);
    }

    // 🔥 Show hint number if cell is hinted, empty, and has a suggestion
    final hintNumber = widget.controller.gameState.hintNumber;
    if (isHintedCell && hintNumber != null && cell.number == null) {
      return buildHintNumber(hintNumber);
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

  Widget buildHintNumber(int number) {
    return Center(
      child: Text(
        number.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4ADE80).withOpacity(0.6),
        ),
      ),
    );
  }

  Widget buildMainNumber(SudokuCell cell, bool isNumberHighlighted) {
    Color numberColor;

    if (isNumberHighlighted) {
      numberColor = Color(0xFFFBBF24); // Yellow for highlighted numbers
    } else if (cell.isGiven) {
      numberColor = widget.theme.textPrimary;
    } else {
      numberColor = widget.theme.textSecondary;
    }

    return Center(
      child: Text(
        cell.number.toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: numberColor,
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

  // 🔥 FIX: Simplified logic - no debug prints, clear priority order
  Color getCellBackgroundColor(
      SudokuCell cell,
      bool isHintedCell,
      bool isRowHighlighted,
      bool isColHighlighted,
      bool isCellHighlighted,
      bool isNumberHighlighted) {
    final selectedNumber = widget.controller.getSelectedNumber();

    // 🔥 PRIORITY ORDER (top to bottom):
    // 1. Hint highlighting (highest priority)
    if (isHintedCell) {
      return Color.fromARGB(255, 3, 181, 208); // Cyan for hinted cell
    }

    if (isRowHighlighted ||
        isColHighlighted ||
        isCellHighlighted ||
        isNumberHighlighted) {
      return Color(0xFF4ADE80); // Green for hint highlights
    }

    // 2. Error state
    if (cell.isError) {
      return Colors.red.shade200;
    }

    // 3. Selection state
    if (cell.isSelected) {
      return widget.theme.selectedColor;
    }

    // 4. Same number highlighting
    if (selectedNumber != null &&
        cell.number == selectedNumber &&
        cell.number != null) {
      return widget.theme.sameNumberColor;
    }

    // 5. Normal highlighting with color
    if (cell.isHighlighted && cell.cellColor != null) {
      return widget.theme.highlightedColor;
    }

    // 6. Normal highlighting without color
    if (cell.isHighlighted) {
      return widget.theme.highlightedColor;
    }

    // 7. Cell color (if set)
    if (cell.cellColor != null) {
      return cell.cellColor!;
    }

    // 8. Default background
    return widget.theme.backgroundColor;
  }
}

/// A sandwich clue: the sum of the digits trapped between the 1 and the 9 in
/// that row or column.
///
/// Drawn as a widget in the gutter beside the board rather than painted from
/// inside a cell. The old per-cell painter tried to draw at a negative offset,
/// which the grid clipped away — the clues were simply never visible.
class SandwichClueLabel extends StatelessWidget {
  final int sum;
  final RealmTheme theme;

  const SandwichClueLabel({
    super.key,
    required this.sum,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Center(
          // Totals run from 0 to 35, so two digits have to fit in a cell-width
          // box however narrow the gutter gets.
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '$sum',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for rendering constraints within a single cell
class CellConstraintPainter extends CustomPainter {
  final List<VariantConstraint> constraints;
  final int row;
  final int col;

  CellConstraintPainter({
    required this.constraints,
    required this.row,
    required this.col,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width;

    for (var constraint in constraints) {
      switch (constraint.type) {
        case ConstraintType.KROPKI_WHITE:
        case ConstraintType.KROPKI_BLACK:
          _paintKropkiDotIfRelevant(canvas, constraint, cellSize);
          break;
        case ConstraintType.XV_X:
        case ConstraintType.XV_V:
          _paintXVIfRelevant(canvas, constraint, cellSize);
          break;
        case ConstraintType.GERMAN_WHISPERS:
          _paintGermanWhispersIfRelevant(canvas, constraint, cellSize);
          break;
        case ConstraintType.THERMO:
          _paintThermoIfRelevant(canvas, constraint, cellSize);
          break;
        case ConstraintType.SANDWICH:
          // Nothing to draw inside a cell — sandwich clues live in the gutter
          // outside the board and are rendered by SandwichClueLabel.
          break;
      }
    }
  }

  void _paintKropkiDotIfRelevant(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    bool isRelevant = false;
    Offset? dotCenter;
    final dotRadius = cellSize * 0.12;

    if (constraint.orientation == 'horizontal') {
      if (row == constraint.row1) {
        if (col == constraint.col1) {
          dotCenter = Offset(cellSize, cellSize / 2);
          isRelevant = true;
        } else if (col == constraint.col2) {
          dotCenter = Offset(0, cellSize / 2);
          isRelevant = true;
        }
      }
    } else {
      if (col == constraint.col1) {
        if (row == constraint.row1) {
          dotCenter = Offset(cellSize / 2, cellSize);
          isRelevant = true;
        } else if (row == constraint.row2) {
          dotCenter = Offset(cellSize / 2, 0);
          isRelevant = true;
        }
      }
    }

    if (!isRelevant || dotCenter == null) return;

    final dotColor = constraint.type == ConstraintType.KROPKI_WHITE
        ? Colors.white
        : Colors.black;

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

  void _paintXVIfRelevant(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    bool isRelevant = false;
    Offset? center;

    if (constraint.orientation == 'horizontal') {
      if (row == constraint.row1) {
        if (col == constraint.col1) {
          center = Offset(cellSize, cellSize / 2);
          isRelevant = true;
        } else if (col == constraint.col2) {
          center = Offset(0, cellSize / 2);
          isRelevant = true;
        }
      }
    } else {
      if (col == constraint.col1) {
        if (row == constraint.row1) {
          center = Offset(cellSize / 2, cellSize);
          isRelevant = true;
        } else if (row == constraint.row2) {
          center = Offset(cellSize / 2, 0);
          isRelevant = true;
        }
      }
    }

    if (!isRelevant || center == null) return;

    final isX = constraint.type == ConstraintType.XV_X;
    final text = isX ? 'X' : 'V';

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
  }

  void _paintGermanWhispersIfRelevant(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    // Check if this cell is one of the two cells in this constraint
    bool isCell1 = (row == constraint.row1 && col == constraint.col1);
    bool isCell2 = (row == constraint.row2 && col == constraint.col2);

    if (!isCell1 && !isCell2) return;

    final paint = Paint()
      ..color = Color(0xFF22c55e)
      ..strokeWidth = cellSize * 0.15
      ..strokeCap = StrokeCap.round;

    if (isCell1) {
      // Draw from center of this cell towards cell2
      final dx = constraint.col2 - constraint.col1;
      final dy = constraint.row2 - constraint.row1;

      final start = Offset(cellSize / 2, cellSize / 2);
      final end = Offset(
        cellSize / 2 + (dx * cellSize / 2),
        cellSize / 2 + (dy * cellSize / 2),
      );

      canvas.drawLine(start, end, paint);
    }

    if (isCell2) {
      // Draw from the edge (coming from cell1) to center of this cell
      final dx = constraint.col2 - constraint.col1;
      final dy = constraint.row2 - constraint.row1;

      final start = Offset(
        cellSize / 2 - (dx * cellSize / 2),
        cellSize / 2 - (dy * cellSize / 2),
      );
      final end = Offset(cellSize / 2, cellSize / 2);

      canvas.drawLine(start, end, paint);
    }
  }

  void _paintThermoIfRelevant(
      Canvas canvas, VariantConstraint constraint, double cellSize) {
    if (constraint.thermoCells == null || constraint.thermoCells!.isEmpty) {
      return;
    }

    final cells = constraint.thermoCells!;
    final thisCellPos = Position(row, col);

    int cellIndex = -1;
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == thisCellPos) {
        cellIndex = i;
        break;
      }
    }

    if (cellIndex == -1) return;

    // A single flat track and a plain bulb. The old version stacked a thick
    // line, a separate border stroke, a radial-gradient bulb, a glow and a
    // shine highlight per cell — clear, but noisy and heavy on the eye. One calm
    // tone reads just as clearly and lets the digits stay the focus.
    const track = Color(0xFF9FB0C4);
    final center = Offset(cellSize / 2, cellSize / 2);

    final linePaint = Paint()
      ..color = track
      ..strokeWidth = cellSize * 0.24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Half-segment toward the previous cell, and half toward the next, so
    // adjacent cells meet cleanly at the shared border.
    if (cellIndex > 0) {
      final prev = cells[cellIndex - 1];
      canvas.drawLine(
        center,
        Offset(
          cellSize / 2 - (col - prev.col) * cellSize / 2,
          cellSize / 2 - (row - prev.row) * cellSize / 2,
        ),
        linePaint,
      );
    }

    if (cellIndex < cells.length - 1) {
      final next = cells[cellIndex + 1];
      canvas.drawLine(
        center,
        Offset(
          cellSize / 2 + (next.col - col) * cellSize / 2,
          cellSize / 2 + (next.row - row) * cellSize / 2,
        ),
        linePaint,
      );
    }

    // The bulb: a single filled disc a little wider than the track, so the
    // start of the thermometer is obvious without any gloss.
    if (cellIndex == 0) {
      canvas.drawCircle(
        center,
        cellSize * 0.30,
        Paint()
          ..color = track
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(CellConstraintPainter oldDelegate) {
    return oldDelegate.row != row ||
        oldDelegate.col != col ||
        oldDelegate.constraints != constraints;
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
