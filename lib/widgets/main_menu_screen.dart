import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  // Control background dimness (0.0 = no dim, 1.0 = fully black)
  final double backgroundDimness = 0.4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'images/castle_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // Dimming overlay (adjustable)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(backgroundDimness),
            ),
          ),

          // Main content
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // Title at top
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 80.0, bottom: 40.0, left: 20.0, right: 20.0),
                    child: Column(
                      children: [
                        Text(
                          'Sudoku',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB4975A), // Gold/secondary color
                            letterSpacing: 2,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black.withOpacity(0.6),
                                offset: Offset(0, 4),
                              ),
                            ],
                            fontFamily: 'CinzelDecorative',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Realms',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB4975A), // Gold/secondary color
                            letterSpacing: 2,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black.withOpacity(0.6),
                                offset: Offset(0, 4),
                              ),
                            ],
                            fontFamily: 'CinzelDecorative',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push buttons to bottom
                  Spacer(),

                  // Buttons at bottom
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 360),
                      child: Column(
                        children: [
                          MenuButton(
                            text: 'Play',
                            icon: Icons.sports_esports,
                            onPressed: () {
                              Navigator.pushNamed(context, '/realm-selection');
                            },
                          ),
                          SizedBox(height: 12),
                          MenuButton(
                            text: 'Statistics',
                            icon: Icons.bar_chart,
                            onPressed: () {
                              Navigator.pushNamed(context, '/statistics');
                            },
                          ),
                          SizedBox(height: 12),
                          MenuButton(
                            text: 'Tips & Tricks',
                            icon: Icons.menu_book,
                            onPressed: () {
                              Navigator.pushNamed(context, '/tips');
                            },
                          ),
                          SizedBox(height: 12),
                          MenuButton(
                            text: 'Settings',
                            icon: Icons.settings,
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings');
                            },
                          ),
                        ],
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
    );
  }
}

class MenuButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const MenuButton({
    Key? key,
    required this.text,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? Color(0xFF6D9DC5).withOpacity(0.8) // Primary color on hover
                : Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? Color(0xFFB4975A) // Gold border on hover
                  : Color(0xFFB4975A).withOpacity(0.5),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Color(0xFFB4975A).withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isHovered
                    ? Colors.white
                    : Color(0xFFB4975A), // Gold icon, white on hover
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                widget.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.015,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Example usage in main.dart:
// 
// void main() {
//   runApp(SudokuRealmsApp());
// }
//
// class SudokuRealmsApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Sudoku Realms',
//       theme: ThemeData(
//         primaryColor: Color(0xFF6D9DC5),
//         colorScheme: ColorScheme.light(
//           primary: Color(0xFF6D9DC5),
//           secondary: Color(0xFFB4975A),
//         ),
//       ),
//       home: MainMenuScreen(),
//       routes: {
//         '/new-game': (context) => NewGameScreen(),
//         '/continue': (context) => ContinueScreen(),
//         '/statistics': (context) => StatisticsScreen(),
//         '/tips': (context) => TipsScreen(),
//         '/settings': (context) => SettingsScreen(),
//       },
//     );
//   }
// }