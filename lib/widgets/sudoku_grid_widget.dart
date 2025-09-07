import 'package:flutter/material.dart';
import '../models/sudoku_cell.dart';
import '../services/game_logic_service.dart';

class SudokuGridWidget extends StatefulWidget {
  final List<List<SudokuCell>> grid;
  final Set<String> selectedCells;
  final Set<String> highlightedCells;
  final Function(int, int) onCellTapped;
  final Function(int, int) onCellDragStart;
  final Function(int, int) onCellDragUpdate;
  final VoidCallback onCellDragEnd;

  const SudokuGridWidget({
    Key? key,
    required this.grid,
    required this.selectedCells,
    required this.highlightedCells,
    required this.onCellTapped,
    required this.onCellDragStart,
    required this.onCellDragUpdate,
    required this.onCellDragEnd,
  }) : super(key: key);

  @override
  State<SudokuGridWidget> createState() => _SudokuGridWidgetState();
}

class _SudokuGridWidgetState extends State<SudokuGridWidget> {
  @override
  void initState() {
    super.initState();
    // Detect conflicts when grid changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameLogicService.detectConflicts(widget.grid);
    });
  }

  @override
  void didUpdateWidget(SudokuGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect conflicts when grid changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameLogicService.detectConflicts(widget.grid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: Column(
          children: List.generate(9, (row) => 
            Expanded(
              child: Row(
                children: List.generate(9, (col) => 
                  Expanded(
                    child: _buildCell(row, col),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final cell = widget.grid[row][col];
    final cellKey = '$row-$col';
    final isSelected = widget.selectedCells.contains(cellKey);
    final isHighlighted = widget.highlightedCells.contains(cellKey);
    
    return GestureDetector(
      onTap: () => widget.onCellTapped(row, col),
      onPanStart: (_) => widget.onCellDragStart(row, col),
      onPanUpdate: (_) => widget.onCellDragUpdate(row, col),
      onPanEnd: (_) => widget.onCellDragEnd(),
      child: Container(
        decoration: BoxDecoration(
          color: _getCellColor(cell, isSelected, isHighlighted),
          border: _getCellBorder(row, col),
        ),
        child: _buildCellContent(cell),
      ),
    );
  }

  Color _getCellColor(SudokuCell cell, bool isSelected, bool isHighlighted) {
    if (isSelected) {
      return Colors.blue[800]!;
    } else if (isHighlighted) {
      return Colors.blue[100]!;
    } else if (cell.hasConflict) {
      return Colors.red[100]!;
    } else if (cell.colorHighlight > 0) {
      return _getColorFromNumber(cell.colorHighlight);
    } else {
      return Colors.white;
    }
  }

  Color _getColorFromNumber(int number) {
    switch (number) {
      case 1: return Colors.red[100]!;
      case 2: return Colors.blue[100]!;
      case 3: return Colors.green[100]!;
      case 4: return Colors.yellow[100]!;
      case 5: return Colors.orange[100]!;
      case 6: return Colors.purple[100]!;
      case 7: return Colors.pink[100]!;
      case 8: return Colors.grey[100]!;
      case 9: return Colors.brown[100]!;
      default: return Colors.white;
    }
  }

  Border _getCellBorder(int row, int col) {
    final borders = <BorderSide>[];
    
    // Top border
    if (row == 0) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else if (row % 3 == 0) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else {
      borders.add(const BorderSide(color: Colors.grey, width: 1));
    }
    
    // Bottom border
    if (row == 8) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else if ((row + 1) % 3 == 0) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else {
      borders.add(const BorderSide(color: Colors.grey, width: 1));
    }
    
    // Left border
    if (col == 0) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else if (col % 3 == 0) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else {
      borders.add(const BorderSide(color: Colors.grey, width: 1));
    }
    
    // Right border
    if (col == 8) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else if ((col + 1) % 3 == 0) {
      borders.add(const BorderSide(color: Colors.black, width: 2));
    } else {
      borders.add(const BorderSide(color: Colors.grey, width: 1));
    }
    
    return Border(
      top: borders[0],
      bottom: borders[1],
      left: borders[2],
      right: borders[3],
    );
  }

  Widget _buildCellContent(SudokuCell cell) {
    if (cell.digit != null) {
      return Center(
        child: Text(
          cell.digit.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: cell.isGiven ? FontWeight.bold : FontWeight.normal,
            color: cell.isGiven ? Colors.black : Colors.blue[800],
          ),
        ),
      );
    } else if (cell.centerMarks.isNotEmpty) {
      return _buildCenterMarks(cell.centerMarks);
    } else if (cell.cornerMarks.isNotEmpty) {
      return _buildCornerMarks(cell.cornerMarks);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildCenterMarks(Set<int> marks) {
    final sortedMarks = marks.toList()..sort();
    return Center(
      child: Text(
        sortedMarks.join(''),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCornerMarks(Set<int> marks) {
    final sortedMarks = marks.toList()..sort();
    final positions = _getCornerPositions(sortedMarks);
    
    return Stack(
      children: positions.map((position) => 
        Positioned(
          left: position.left,
          top: position.top,
          child: Text(
            position.number.toString(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ),
      ).toList(),
    );
  }

  List<_CornerPosition> _getCornerPositions(List<int> numbers) {
    final positions = <_CornerPosition>[];
    
    for (int i = 0; i < numbers.length && i < 9; i++) {
      double left, top;
      
      switch (i) {
        case 0: // Top-left
          left = 2; top = 2;
          break;
        case 1: // Top-right
          left = 20; top = 2;
          break;
        case 2: // Bottom-left
          left = 2; top = 20;
          break;
        case 3: // Bottom-right
          left = 20; top = 20;
          break;
        case 4: // Top-center
          left = 11; top = 2;
          break;
        case 5: // Bottom-center
          left = 11; top = 20;
          break;
        case 6: // Left-center
          left = 2; top = 11;
          break;
        case 7: // Right-center
          left = 20; top = 11;
          break;
        case 8: // Center
          left = 11; top = 11;
          break;
        default:
          continue;
      }
      
      positions.add(_CornerPosition(
        number: numbers[i],
        left: left,
        top: top,
      ));
    }
    
    return positions;
  }
}

class _CornerPosition {
  final int number;
  final double left;
  final double top;
  
  _CornerPosition({
    required this.number,
    required this.left,
    required this.top,
  });
}
