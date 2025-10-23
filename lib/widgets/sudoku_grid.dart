// File path: lib/widgets/sudoku_grid.dart
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../models/sudoku_cell.dart';
import '../models/position.dart';

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
  // 🔥 NEW: Drag selection tracking
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
    print('===== _onGameStateChanged called in SudokuGrid =====');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print('===== SudokuGrid BUILD called =====');
    return Padding(
      padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 50), //top:50 is used in order to be correctly centered
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
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
      ),
    );
  }

  // 🔥 MODIFIED: Prevent tap from firing after drag
  void onCellTap(int row, int col) {
    // Don't process tap if we just finished a drag
    if (_draggedCells.length > 1) {
      return;
    }

    widget.controller.handleCellTap(row, col);
  }

  // 🔥 NEW: Drag start handler
  void onCellDragStart(int row, int col) {
    print('🖐️ Drag started at ($row, $col)');
    setState(() {
      _isDragging = true;
      _draggedCells.clear();
    });

    // Select the starting cell
    final pos = Position(row, col);
    _draggedCells.add(pos);

    // Clear previous selection and select just this cell
    widget.controller.gameState.selectedCells.clear();
    widget.controller.gameState.selectedCells.add(pos);

    widget.controller.updateHighlights();
  }

  // 🔥 NEW: Drag update handler
  void onCellDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    // Get the render box to calculate position
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);

    // 🔥 ACCOUNT FOR TOP PADDING (50 pixels)
    final adjustedY = localPosition.dy - 50;

    // Calculate cell size (assuming square cells)
    // Use width minus horizontal padding (16 left + 16 right = 32)
    final cellSize = (box.size.width - 32) / 9;

    // Calculate which cell we're over
    final col = ((localPosition.dx - 16) / cellSize).floor().clamp(0, 8);
    final row = (adjustedY / cellSize).floor().clamp(0, 8);

    final pos = Position(row, col);

    // Only update if this is a new cell
    if (!_draggedCells.contains(pos)) {
      print('🖐️ Dragged to ($row, $col)');
      setState(() {
        _draggedCells.add(pos);
      });

      // Update selection with all dragged cells
      widget.controller.gameState.selectedCells.clear();
      widget.controller.gameState.selectedCells.addAll(_draggedCells);

      widget.controller.updateHighlights();
    }
  }

  // 🔥 NEW: Drag end handler
  void onCellDragEnd() {
    print('🖐️ Drag ended - ${_draggedCells.length} cells selected');

    // Small delay to prevent tap from firing
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
    // If there's a main number, show it
    if (cell.number != null) {
      return buildMainNumber(cell);
    }

    // Otherwise, show notes (both types if they exist)
    final hasSideNotes = cell.sideNotes.isNotEmpty;
    final hasCenterNotes = cell.centerNotes.isNotEmpty;

    if (hasSideNotes && hasCenterNotes) {
      // Show BOTH side and center notes
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

    // Split notes into two rows (top gets extra if odd count)
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
          // Top row
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

          // Bottom row
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

    // Calculate font size based on number of notes
    // Fewer notes = bigger font, more notes = smaller font
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
    // NEW: If selected AND colored, show thick colored border
    if (cell.isSelected && cell.cellColor != null) {
      return Border.all(
        width: 4,
        color: cell.cellColor!,
      );
    }

    // If highlighted AND colored, show thick colored border
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
    // Get the selected number to highlight
    final selectedNumber = widget.controller.getSelectedNumber();

    Color color;

    // Priority 1: Error (shows for conflicts)
    if (cell.isError) {
      color = Colors.red.shade200;
    }
    // Priority 2: Selected
    else if (cell.isSelected) {
      color = Colors.blue.shade600;
    }
    // Priority 3: Same number as selected (NEW!)
    else if (selectedNumber != null &&
        cell.number == selectedNumber &&
        cell.number != null) {
      color = Colors.blue.shade200; // Light blue for matching numbers
    }
    // Priority 4: Highlighted + Colored
    else if (cell.isHighlighted && cell.cellColor != null) {
      color = Colors.blue.shade100;
    }
    // Priority 5: Highlighted
    else if (cell.isHighlighted) {
      color = Colors.blue.shade100;
    }
    // Priority 6: Colored
    else if (cell.cellColor != null) {
      color = cell.cellColor!;
    }
    // Priority 7: Default
    else {
      color = Colors.white;
    }

    return color;
  }
}
