import 'package:flutter/material.dart';
import '../data/realm_config.dart';

class RealmSelectionScreen extends StatefulWidget {
  const RealmSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RealmSelectionScreen> createState() => _RealmSelectionScreenState();
}

class _RealmSelectionScreenState extends State<RealmSelectionScreen> {
  int selectedRealmIndex = 0;

  final List<Map<String, String>> realms = [
    {
      'name': 'Classic Kingdom',
      'image':
          'images/realms/classic_kingdom.png', // TODO: Add your realm images
    },
    {
      'name': 'Kropki Forest',
      'image': 'images/realms/kropki_forest.png',
    },
    {
      'name': 'Thermo Desert',
      'image': 'images/realms/thermo_desert.png',
    },
    {
      'name': 'German Whispers Mountains',
      'image': 'images/realms/german_whispers.png',
    },
    {
      'name': 'XV Sky Islands',
      'image': 'images/realms/xv_sky_islands.png',
    },
    {
      'name': 'Aqua Labyrinth',
      'image': 'images/realms/aqua_labyrinth.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'images/castle.jpg', // TODO: Add your background image
              fit: BoxFit.cover,
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF221c10).withOpacity(0.2),
                    Color(0xFF221c10).withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              // Header with back button and title
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Color(0xFFf8f7f6)),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        iconSize: 28,
                      ),
                      // Title
                      Expanded(
                        child: Text(
                          'Choose Your Realm',
                          style: TextStyle(
                            color: Color(0xFFf8f7f6),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.015,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Spacer to balance the back button
                      SizedBox(width: 48),
                    ],
                  ),
                ),
              ),

              // Realm grid
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3 / 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: realms.length,
                        itemBuilder: (context, index) {
                          return RealmCard(
                            realm: realms[index],
                            isSelected: selectedRealmIndex == index,
                            onTap: () {
                              setState(() {
                                selectedRealmIndex = index;
                              });
                            },
                          );
                        },
                      ),

                      // Scroll indicator
                      Padding(
                        padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.expand_more,
                              color: Color(0xFFf8f7f6).withOpacity(0.5),
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Scroll for more',
                              style: TextStyle(
                                color: Color(0xFFf8f7f6).withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom button with gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xFF221c10),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to game with selected realm
                          Navigator.pushNamed(
                            context,
                            '/level-selection',
                            arguments: {
                              'realmName': realms[selectedRealmIndex]['name']!,
                              'puzzles': RealmConfig.getPuzzlesForRealm(
                                  realms[selectedRealmIndex]['name']!),
                            },
                          );
                          // ====================================================
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFeca413),
                          foregroundColor: Color(0xFF181611),
                          elevation: 0,
                          shadowColor: Color(0xFFeca413).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Start Adventure',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.015,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RealmCard extends StatefulWidget {
  final Map<String, String> realm;
  final bool isSelected;
  final VoidCallback onTap;

  const RealmCard({
    Key? key,
    required this.realm,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  State<RealmCard> createState() => _RealmCardState();
}

class _RealmCardState extends State<RealmCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool shouldGlow = widget.isSelected || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: shouldGlow
                ? Border.all(
                    color: Color(0xFFeca413),
                    width: 2,
                  )
                : null,
            boxShadow: shouldGlow
                ? [
                    BoxShadow(
                      color: Color(0xFFeca413).withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Realm image
                Positioned.fill(
                  child: Image.asset(
                    widget.realm['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Placeholder gradient if image not found
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF4a4a4a),
                              Color(0xFF2a2a2a),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF181611).withOpacity(0.0),
                          Color(0xFF181611).withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Realm name
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    widget.realm['name']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Example usage - Add to your routes:
// '/realm-selection': (context) => RealmSelectionScreen(),
// '/game': (context) => GameScreen(),
