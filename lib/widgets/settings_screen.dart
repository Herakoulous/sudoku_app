import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import '../services/save_service.dart';
import '../services/audio_service.dart';
import '../widgets/color_customization_screen.dart';
import '../widgets/realm_color_customization_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _showMistakes = true;
  bool _showTimer = true;
  bool _autoNotes = true;
  bool _soundEffects = true;
  bool _music = true;
  String _theme = 'auto';
  String _resolvedTheme = 'dark'; // Actual theme (dark/light)

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    AudioService.startBackgroundMusic();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getAllSettings();
    final resolvedTheme = await SettingsService.getResolvedTheme(context);

    setState(() {
      _showMistakes = settings['showMistakes'];
      _showTimer = settings['showTimer'];
      _autoNotes = settings['autoNotes'];
      _soundEffects = settings['soundEffects'];
      _music = settings['music'];
      _theme = settings['theme'];
      _resolvedTheme = resolvedTheme;
      _isLoading = false;
    });
  }

  Future<void> _updateShowMistakes(bool value) async {
    await AudioService.playToggleSound();
    await SettingsService.setShowMistakes(value);
    setState(() => _showMistakes = value);
  }

  Future<void> _updateShowTimer(bool value) async {
    await AudioService.playToggleSound();
    await SettingsService.setShowTimer(value);
    setState(() => _showTimer = value);
  }

  Future<void> _updateAutoNotes(bool value) async {
    await AudioService.playToggleSound();
    await SettingsService.setAutoNotes(value);
    setState(() => _autoNotes = value);
  }

  Future<void> _updateSoundEffects(bool value) async {
    if (!value) await AudioService.playToggleSound();
    await SettingsService.setSoundEffects(value);
    setState(() => _soundEffects = value);
    if (value) await AudioService.playToggleSound();
  }

  Future<void> _updateMusic(bool value) async {
    await AudioService.playToggleSound();
    await SettingsService.setMusic(value);
    setState(() => _music = value);
    await AudioService.toggleBackgroundMusic(value);
  }

  Future<void> _updateTheme(String value) async {
    await AudioService.playButtonSound();
    await SettingsService.setTheme(value);
    final resolvedTheme = await SettingsService.getResolvedTheme(context);
    setState(() {
      _theme = value;
      _resolvedTheme = resolvedTheme;
    });
  }

  Future<void> _showThemeDialog() async {
    await AudioService.playTapSound();
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _buildThemeDialog(),
    );

    if (selected != null && selected != _theme) {
      await _updateTheme(selected);
    }
  }

  Widget _buildThemeDialog() {
    return AlertDialog(
      backgroundColor: _getBackgroundColor().withOpacity(0.95),
      title: Text(
        'Select Theme',
        style: TextStyle(color: Color(0xFFB4975A)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeOption('Auto (System)', 'auto'),
          SizedBox(height: 8),
          _buildThemeOption('Dark', 'dark'),
          SizedBox(height: 8),
          _buildThemeOption('Light', 'light'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildThemeOption(String label, String value) {
    final isSelected = _theme == value;
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFFB4975A).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Color(0xFFB4975A)
                : _getBorderColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Color(0xFFB4975A) : Colors.grey,
            ),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: _getTextColor(),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreDefaults() async {
    await AudioService.playTapSound();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _getBackgroundColor().withOpacity(0.95),
        title: Text(
          'Restore Defaults',
          style: TextStyle(color: Color(0xFFB4975A)),
        ),
        content: Text(
          'Are you sure you want to restore all settings to their default values?',
          style: TextStyle(color: _getTextColor()),
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
            child: Text('Restore', style: TextStyle(color: Color(0xFFB4975A))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SettingsService.restoreDefaults();
      await _loadSettings();
      await AudioService.toggleBackgroundMusic(_music);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings restored to defaults'),
            backgroundColor: Color(0xFF6D9DC5),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteProgress() async {
    await AudioService.playTapSound();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _getBackgroundColor().withOpacity(0.95),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Delete Progress',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(
                color: _getTextColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildWarningItem('All saved games'),
            _buildWarningItem('All completion records'),
            _buildWarningItem('All best times'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              AudioService.playErrorSound();
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            child: Text(
              'Delete All',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final savedIds = await SaveService.getSavedGameIds();
      final completedIds = await SaveService.getCompletedPuzzleIds();

      for (final id in savedIds) {
        await SaveService.clearSave(id);
      }

      final prefs = await SharedPreferences.getInstance();
      for (final id in completedIds) {
        await prefs.remove('sudoku_completed_$id');
        await prefs.remove('sudoku_best_time_$id');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('All progress has been deleted'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        children: [
          Icon(Icons.close, color: Colors.red, size: 16),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: _getTextColor()),
          ),
        ],
      ),
    );
  }

  // Theme-aware color getters
  Color _getBackgroundColor() {
    return _resolvedTheme == 'dark' ? Colors.black : Colors.white;
  }

  Color _getTextColor() {
    return _resolvedTheme == 'dark' ? Colors.white : Colors.black;
  }

  Color _getSecondaryTextColor() {
    return _resolvedTheme == 'dark' ? Color(0xFFd6d3d1) : Color(0xFF57534e);
  }

  Color _getBorderColor() {
    return _resolvedTheme == 'dark' ? Color(0xFF78716c) : Color(0xFFa8a29e);
  }

  Color _getSectionBackgroundColor() {
    return _resolvedTheme == 'dark'
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.7);
  }

  Color _getToggleActiveColor() {
    return Color(0xFFB4975A);
  }

  Color _getToggleInactiveColor() {
    return _resolvedTheme == 'dark'
        ? Color(0xFF78716c).withOpacity(0.5)
        : Color(0xFFa8a29e);
  }

  Color _getToggleThumbColor() {
    return _resolvedTheme == 'dark' ? Color(0xFF1c1917) : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _getBackgroundColor(),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB4975A)),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: _getBackgroundColor(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          'Gameplay',
                          [
                            _buildToggle('Show mistakes', _showMistakes,
                                _updateShowMistakes),
                            _buildDivider(),
                            _buildToggle(
                                'Show timer', _showTimer, _updateShowTimer),
                            _buildDivider(),
                            _buildToggle(
                                'Auto notes', _autoNotes, _updateAutoNotes),
                          ],
                        ),
                        SizedBox(height: 24),
                        _buildSection(
                          'Appearance',
                          [
                            _buildThemeSelector(),
                            _buildDivider(),
                            _buildColorCustomization(),
                          ],
                        ),
                        SizedBox(height: 24),
                        _buildSection(
                          'Sound & Feedback',
                          [
                            _buildToggle('Sound effects', _soundEffects,
                                _updateSoundEffects),
                            _buildDivider(),
                            _buildToggle('Music', _music, _updateMusic),
                          ],
                        ),
                        SizedBox(height: 32),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: _buildBackButton(),
                ),
              ],
            ),
          ),
        ],
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
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB4975A),
                letterSpacing: 2,
                fontFamily: 'CinzelDecorative',
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getTextColor().withOpacity(0.8),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _getSectionBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getBorderColor().withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: _getTextColor(),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 51,
              height: 31,
              decoration: BoxDecoration(
                color:
                    value ? _getToggleActiveColor() : _getToggleInactiveColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 27,
                  height: 27,
                  margin: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _getToggleThumbColor(),
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

  Widget _buildThemeSelector() {
    String displayText = _theme == 'auto'
        ? 'Auto (System)'
        : (_theme == 'dark' ? 'Dark' : 'Light');

    return GestureDetector(
      onTap: _showThemeDialog,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Theme',
              style: TextStyle(
                fontSize: 16,
                color: _getTextColor(),
              ),
            ),
            Row(
              children: [
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 16,
                    color: _getSecondaryTextColor(),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Color(0xFFB4975A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCustomization() {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            await AudioService.playTapSound();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ColorCustomizationScreen(),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.grid_on,
                      color: Color(0xFFB4975A),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Grid Colors',
                      style: TextStyle(
                        fontSize: 16,
                        color: _getTextColor(),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: Color(0xFFB4975A),
                ),
              ],
            ),
          ),
        ),
        _buildDivider(),
        GestureDetector(
          onTap: () async {
            await AudioService.playTapSound();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RealmColorCustomizationScreen(),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette,
                      color: Color(0xFFB4975A),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Realm Colors',
                      style: TextStyle(
                        fontSize: 16,
                        color: _getTextColor(),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: Color(0xFFB4975A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Divider(
        color: _getBorderColor().withOpacity(0.5),
        height: 1,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Restore Defaults',
            Icons.settings_backup_restore,
            Colors.grey,
            _restoreDefaults,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Delete Progress',
            Icons.delete_forever,
            Colors.red,
            _deleteProgress,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
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
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          'Back to Menu',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _getToggleThumbColor(),
            letterSpacing: 2,
            fontFamily: 'CinzelDecorative',
          ),
        ),
      ),
    );
  }
}
