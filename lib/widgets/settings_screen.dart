import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showMistakes = true;
  bool _showTimer = true;
  bool _autoNotes = false;
  bool _soundEffects = true;
  bool _music = false;
  bool _realmBackgrounds = true;
  String _theme = 'dark';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getAllSettings();
    setState(() {
      _showMistakes = settings['showMistakes'] ?? true;
      _showTimer = settings['showTimer'] ?? true;
      _autoNotes = settings['autoNotes'] ?? false;
      _soundEffects = settings['soundEffects'] ?? true;
      _music = settings['music'] ?? false;
      _realmBackgrounds = settings['realmBackgrounds'] ?? true;
      _theme = settings['theme'] ?? 'dark';
      _isLoading = false;
    });
  }

  Future<void> _updateShowMistakes(bool value) async {
    await SettingsService.setShowMistakes(value);
    setState(() => _showMistakes = value);
  }

  Future<void> _updateShowTimer(bool value) async {
    await SettingsService.setShowTimer(value);
    setState(() => _showTimer = value);
  }

  Future<void> _updateAutoNotes(bool value) async {
    await SettingsService.setAutoNotes(value);
    setState(() => _autoNotes = value);
  }

  Future<void> _updateSoundEffects(bool value) async {
    _showFeatureNotAvailableSnackBar();
  }

  // Add this method after _loadSettings():
  void _showFeatureNotAvailableSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Feature not available. \n Thank you for your understanding.',
                style: TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

// Replace these methods:
  Future<void> _updateMusic(bool value) async {
    _showFeatureNotAvailableSnackBar();
  }

  Future<void> _updateRealmBackgrounds(bool value) async {
    _showFeatureNotAvailableSnackBar();
  }

  Future<void> _updateTheme(String? value) async {
    _showFeatureNotAvailableSnackBar();
  }

  Future<void> _restoreDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore Defaults'),
        content: Text(
            'Are you sure you want to restore all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SettingsService.restoreDefaults();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings restored to defaults')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image with dimming
          Positioned.fill(
            child: Image.asset(
              'images/castle_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Color(0xFFB4975A)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB4975A),
                          fontFamily: 'CinzelDecorative',
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings list
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFB4975A),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildSection(
                                title: 'GAMEPLAY',
                                children: [
                                  _buildSwitchTile(
                                    title: 'Show Mistakes',
                                    subtitle:
                                        'Highlight incorrect numbers in red',
                                    value: _showMistakes,
                                    onChanged: _updateShowMistakes,
                                  ),
                                  _buildSwitchTile(
                                    title: 'Show Timer',
                                    subtitle:
                                        'Display elapsed time during gameplay',
                                    value: _showTimer,
                                    onChanged: _updateShowTimer,
                                  ),
                                  _buildSwitchTile(
                                    title: 'Auto Notes',
                                    subtitle:
                                        'Auto-erase notes when placing numbers',
                                    value: _autoNotes,
                                    onChanged: _updateAutoNotes,
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              _buildSection(
                                title: 'AUDIO',
                                children: [
                                  _buildSwitchTile(
                                    title: 'Sound Effects',
                                    subtitle: 'Play sound effects for actions',
                                    value: _soundEffects,
                                    onChanged: _updateSoundEffects,
                                  ),
                                  _buildSwitchTile(
                                    title: 'Music',
                                    subtitle: 'Play background music',
                                    value: _music,
                                    onChanged: _updateMusic,
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              _buildSection(
                                title: 'APPEARANCE',
                                children: [
                                  _buildSwitchTile(
                                    title: 'Realm Backgrounds',
                                    subtitle:
                                        'Show themed backgrounds in menus',
                                    value: _realmBackgrounds,
                                    onChanged: _updateRealmBackgrounds,
                                  ),
                                  _buildThemeTile(),
                                ],
                              ),
                              SizedBox(height: 32),
                              // Restore defaults button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _restoreDefaults,
                                  icon: Icon(Icons.restore),
                                  label: Text('Restore Defaults'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.black.withOpacity(0.6),
                                    foregroundColor: Color(0xFFB4975A),
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color:
                                            Color(0xFFB4975A).withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 32),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB4975A).withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFB4975A).withOpacity(0.3),
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Color(0xFFB4975A),
        activeTrackColor: Color(0xFFB4975A).withOpacity(0.5),
      ),
    );
  }

  Widget _buildThemeTile() {
    return ListTile(
      title: Text(
        'Theme',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Choose your preferred color scheme',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
      trailing: DropdownButton<String>(
        value: _theme,
        dropdownColor: Colors.black87,
        style: TextStyle(color: Color(0xFFB4975A)),
        underline: Container(),
        items: [
          DropdownMenuItem(value: 'dark', child: Text('Dark')),
          DropdownMenuItem(value: 'light', child: Text('Light')),
          DropdownMenuItem(value: 'auto', child: Text('Auto')),
        ],
        onChanged: (value) {
          if (value != null) _updateTheme(value);
        },
      ),
    );
  }
}
