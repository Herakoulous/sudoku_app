import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import 'package:flutter/services.dart';

class ColorCustomizationScreen extends StatefulWidget {
  const ColorCustomizationScreen({Key? key}) : super(key: key);

  @override
  State<ColorCustomizationScreen> createState() =>
      _ColorCustomizationScreenState();
}

class _ColorCustomizationScreenState extends State<ColorCustomizationScreen> {
  bool _customColorsEnabled = false;
  Color _gridBackground = Colors.white;
  Color _givenNumbers = Colors.black;
  Color _userNumbers = Color(0xFF1e3a8a);
  Color _gridBorders = Colors.black;
  Color _selectedCell = Color(0xFF3b82f6);
  Color _highlightedCell = Color(0xFFdbeafe);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    final enabled = await SettingsService.getCustomColorsEnabled();
    final gridBg = await SettingsService.getGridBackground();
    final givenNums = await SettingsService.getGivenNumbers();
    final userNums = await SettingsService.getUserNumbers();
    final borders = await SettingsService.getGridBorders();
    final selected = await SettingsService.getSelectedCell();
    final highlighted = await SettingsService.getHighlightedCell();

    setState(() {
      _customColorsEnabled = enabled;
      _gridBackground = gridBg;
      _givenNumbers = givenNums;
      _userNumbers = userNums;
      _gridBorders = borders;
      _selectedCell = selected;
      _highlightedCell = highlighted;
      _isLoading = false;
    });
  }

  Future<void> _updateCustomColorsEnabled(bool value) async {
    await AudioService.playToggleSound();
    await SettingsService.setCustomColorsEnabled(value);
    setState(() => _customColorsEnabled = value);
  }

  Future<void> _updateColor(String colorType, Color color) async {
    await AudioService.playTapSound();

    switch (colorType) {
      case 'gridBackground':
        await SettingsService.setGridBackground(color);
        setState(() => _gridBackground = color);
        break;
      case 'givenNumbers':
        await SettingsService.setGivenNumbers(color);
        setState(() => _givenNumbers = color);
        break;
      case 'userNumbers':
        await SettingsService.setUserNumbers(color);
        setState(() => _userNumbers = color);
        break;
      case 'gridBorders':
        await SettingsService.setGridBorders(color);
        setState(() => _gridBorders = color);
        break;
      case 'selectedCell':
        await SettingsService.setSelectedCell(color);
        setState(() => _selectedCell = color);
        break;
      case 'highlightedCell':
        await SettingsService.setHighlightedCell(color);
        setState(() => _highlightedCell = color);
        break;
    }
  }

  Future<void> _showColorPicker(
      String colorType, Color currentColor, String label) async {
    await AudioService.playTapSound();

    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: currentColor,
        label: label,
      ),
    );

    if (selected != null) {
      await _updateColor(colorType, selected);
    }
  }

  Future<void> _resetToDefaults() async {
    await AudioService.playButtonSound();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        title: Text(
          'Reset Colors',
          style: TextStyle(color: Color(0xFFB4975A)),
        ),
        content: Text(
          'Reset all colors to default high-contrast values?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playButtonSound();
              Navigator.pop(context, false);
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              AudioService.playSuccessSound();
              Navigator.pop(context, true);
            },
            child: Text('Reset', style: TextStyle(color: Color(0xFFB4975A))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SettingsService.setGridBackground(Color(0xFFFFFFFF));
      await SettingsService.setGivenNumbers(Color(0xFF000000));
      await SettingsService.setUserNumbers(Color(0xFF1e3a8a));
      await SettingsService.setGridBorders(Color(0xFF000000));
      await SettingsService.setSelectedCell(Color(0xFF3b82f6));
      await SettingsService.setHighlightedCell(Color(0xFFdbeafe));
      await _loadColors();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Colors reset to defaults'),
            backgroundColor: Color(0xFF6D9DC5),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB4975A)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggle(),
                    SizedBox(height: 24),
                    _buildPreview(),
                    SizedBox(height: 24),
                    _buildColorOptions(),
                    SizedBox(height: 24),
                    _buildResetButton(),
                  ],
                ),
              ),
            ),
            _buildBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFFB4975A)),
            onPressed: () {
              AudioService.playButtonSound();
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              'Customize Colors',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB4975A),
                letterSpacing: 1.5,
                fontFamily: 'CinzelDecorative',
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF78716c).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Colors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Use your own color scheme',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _updateCustomColorsEnabled(!_customColorsEnabled),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 51,
              height: 31,
              decoration: BoxDecoration(
                color: _customColorsEnabled
                    ? Color(0xFFB4975A)
                    : Color(0xFF78716c).withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: Duration(milliseconds: 200),
                alignment: _customColorsEnabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 27,
                  height: 27,
                  margin: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Color(0xFF1c1917),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF78716c).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: _gridBackground,
                border: Border.all(color: _gridBorders, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _buildPreviewCell('5', _givenNumbers, _gridBackground),
                        _buildPreviewCell('3', _userNumbers, _selectedCell),
                        _buildPreviewCell('7', _givenNumbers, _highlightedCell),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _buildPreviewCell('6', _givenNumbers, _highlightedCell),
                        _buildPreviewCell('1', _userNumbers, _gridBackground),
                        _buildPreviewCell('9', _givenNumbers, _highlightedCell),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _buildPreviewCell('8', _givenNumbers, _gridBackground),
                        _buildPreviewCell('4', _userNumbers, _gridBackground),
                        _buildPreviewCell('2', _givenNumbers, _gridBackground),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCell(String text, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: _gridBorders.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorOptions() {
    return Opacity(
      opacity: _customColorsEnabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !_customColorsEnabled,
        child: Column(
          children: [
            _buildColorOption(
              'Grid Background',
              _gridBackground,
              'gridBackground',
            ),
            SizedBox(height: 12),
            _buildColorOption(
              'Given Numbers',
              _givenNumbers,
              'givenNumbers',
            ),
            SizedBox(height: 12),
            _buildColorOption(
              'User Numbers',
              _userNumbers,
              'userNumbers',
            ),
            SizedBox(height: 12),
            _buildColorOption(
              'Grid Borders',
              _gridBorders,
              'gridBorders',
            ),
            SizedBox(height: 12),
            _buildColorOption(
              'Selected Cell',
              _selectedCell,
              'selectedCell',
            ),
            SizedBox(height: 12),
            _buildColorOption(
              'Highlighted Cell',
              _highlightedCell,
              'highlightedCell',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(String label, Color color, String colorType) {
    return GestureDetector(
      onTap: () => _showColorPicker(colorType, color, label),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF78716c).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.edit, color: Color(0xFFB4975A), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: _resetToDefaults,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restore, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text(
              'Reset to Defaults',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () {
          AudioService.playButtonSound();
          Navigator.pop(context);
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Color(0xFFB4975A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFB4975A).withOpacity(0.5),
                blurRadius: 15,
              ),
            ],
          ),
          child: Text(
            'Done',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              letterSpacing: 2,
              fontFamily: 'CinzelDecorative',
            ),
          ),
        ),
      ),
    );
  }
}

// Color Picker Dialog
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String label;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.label,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  final List<Color> _commonColors = [
    Colors.white,
    Colors.black,
    Color(0xFF1e3a8a), // Dark blue
    Color(0xFF3b82f6), // Bright blue
    Color(0xFFdbeafe), // Light blue
    Color(0xFFef4444), // Red
    Color(0xFF22c55e), // Green
    Color(0xFFfbbf24), // Yellow
    Color(0xFF8b5cf6), // Purple
    Color(0xFFf97316), // Orange
    Color(0xFF06b6d4), // Cyan
    Color(0xFFec4899), // Pink
    Color(0xFF64748b), // Gray
    Color(0xFFfef3c7), // Light yellow
    Color(0xFFfecaca), // Light red
    Color(0xFFd1fae5), // Light green
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      title: Text(
        widget.label,
        style: TextStyle(color: Color(0xFFB4975A)),
      ),
      content: Container(
        width: 280,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _commonColors.length,
          itemBuilder: (context, index) {
            final color = _commonColors[index];
            final isSelected = color.value == _selectedColor.value;

            return GestureDetector(
              onTap: () {
                AudioService.playTapSound();
                setState(() => _selectedColor = color);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Color(0xFFB4975A)
                        : Colors.white.withOpacity(0.3),
                    width: isSelected ? 3 : 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, color: _getContrastColor(color))
                    : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            AudioService.playButtonSound();
            Navigator.pop(context);
          },
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            AudioService.playSuccessSound();
            Navigator.pop(context, _selectedColor);
          },
          child: Text('Select', style: TextStyle(color: Color(0xFFB4975A))),
        ),
      ],
    );
  }

  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
