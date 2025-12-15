import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../data/realm_config.dart';
import '../services/realm_color_service.dart';

class RealmColorCustomizationScreen extends StatefulWidget {
  const RealmColorCustomizationScreen({Key? key}) : super(key: key);

  @override
  State<RealmColorCustomizationScreen> createState() =>
      _RealmColorCustomizationScreenState();
}

class _RealmColorCustomizationScreenState
    extends State<RealmColorCustomizationScreen> {
  // Store custom colors for each realm
  Map<String, Color> _realmPrimaryColors = {};
  Map<String, Color> _realmAccentColors = {};
  bool _isLoading = true;

  // Get list of all realms
  List<String> get _realms => RealmConfig.realmPuzzles.keys.toList();

  @override
  void initState() {
    super.initState();
    _loadRealmColors();
  }

  Future<void> _loadRealmColors() async {
    for (String realm in _realms) {
      _realmPrimaryColors[realm] =
          await RealmColorService.getPrimaryColor(realm);
      _realmAccentColors[realm] = await RealmColorService.getAccentColor(realm);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateRealmColor(
      String realm, String colorType, Color color) async {
    await AudioService.playTapSound();

    if (colorType == 'primary') {
      await RealmColorService.setPrimaryColor(realm, color);
      setState(() => _realmPrimaryColors[realm] = color);
    } else {
      await RealmColorService.setAccentColor(realm, color);
      setState(() => _realmAccentColors[realm] = color);
    }
  }

  Future<void> _showColorPicker(
      String realm, String colorType, Color currentColor, String label) async {
    await AudioService.playTapSound();

    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: currentColor,
        label: label,
      ),
    );

    if (selected != null) {
      await _updateRealmColor(realm, colorType, selected);
    }
  }

  Future<void> _resetRealmColors(String realm) async {
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
          'Reset colors for $realm to default?',
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
      await RealmColorService.resetRealmColors(realm);
      setState(() {
        _realmPrimaryColors[realm] = RealmConfig.getPrimaryColor(realm);
        _realmAccentColors[realm] = RealmConfig.getAccentColor(realm);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Colors reset for $realm'),
            backgroundColor: Color(0xFF6D9DC5),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _resetAllColors() async {
    await AudioService.playButtonSound();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        title: Text(
          'Reset All Colors',
          style: TextStyle(color: Color(0xFFB4975A)),
        ),
        content: Text(
          'Reset colors for all realms to defaults?',
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
            child:
                Text('Reset All', style: TextStyle(color: Color(0xFFB4975A))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await RealmColorService.resetAllColors();
      await _loadRealmColors();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All realm colors reset to defaults'),
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
                    Text(
                      'Customize realm accent colors',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 20),
                    ..._realms.map((realm) => _buildRealmCard(realm)).toList(),
                    SizedBox(height: 24),
                    _buildResetAllButton(),
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
              'Realm Colors',
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

  Widget _buildRealmCard(String realm) {
    final primaryColor = _realmPrimaryColors[realm]!;
    final accentColor = _realmAccentColors[realm]!;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  realm,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.restore, color: Colors.grey, size: 20),
                onPressed: () => _resetRealmColors(realm),
                tooltip: 'Reset realm colors',
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildColorRow(
            'Primary Color',
            primaryColor,
            () => _showColorPicker(
                realm, 'primary', primaryColor, '$realm Primary'),
          ),
          SizedBox(height: 12),
          _buildColorRow(
            'Accent Color',
            accentColor,
            () =>
                _showColorPicker(realm, 'accent', accentColor, '$realm Accent'),
          ),
          SizedBox(height: 12),
          _buildPreview(primaryColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
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
              Icon(Icons.edit, color: Color(0xFFB4975A), size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(Color primaryColor, Color accentColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Icon(Icons.star, color: primaryColor, size: 32),
              SizedBox(height: 4),
              Text(
                'Primary',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ],
          ),
          Column(
            children: [
              Icon(Icons.star, color: accentColor, size: 32),
              SizedBox(height: 4),
              Text(
                'Accent',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetAllButton() {
    return GestureDetector(
      onTap: _resetAllColors,
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
            Icon(Icons.restore_page, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text(
              'Reset All Realms to Defaults',
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

// Color Picker Dialog (same as before)
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
    Color(0xFFeca413), // Gold
    Color(0xFFfde047), // Light gold
    Color(0xFF22c55e), // Green
    Color(0xFF86efac), // Light green
    Color(0xFFf97316), // Orange
    Color(0xFFfbbf24), // Yellow
    Color(0xFF06b6d4), // Cyan
    Color(0xFF67e8f9), // Light cyan
    Color(0xFF8b5cf6), // Purple
    Color(0xFFc4b5fd), // Light purple
    Color(0xFF3b82f6), // Blue
    Color(0xFF93c5fd), // Light blue
    Color(0xFFef4444), // Red
    Color(0xFFfca5a5), // Light red
    Color(0xFFec4899), // Pink
    Color(0xFFfda4af), // Light pink
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
