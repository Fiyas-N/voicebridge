import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_tokens.dart';
import 'dot_grid_background.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/lessons/lessons_screen.dart';
import '../../screens/progress/progress_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LessonsScreen(),
    ProgressScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  TextStyle _navLabelStyle(Color color) {
    return GoogleFonts.jetBrainsMono(
      fontSize: VbTypography.labelCaps,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VbColor.background,
      body: DotGridBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: VbColor.background,
          border: Border(
            top: BorderSide(color: VbColor.outlineVariant, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: VbColor.accentElectric.withValues(alpha: 0.12),
                highlightColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: VbColor.accentElectric,
                unselectedItemColor: VbColor.onSurfaceVariant,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                selectedLabelStyle:
                    _navLabelStyle(VbColor.accentElectric),
                unselectedLabelStyle:
                    _navLabelStyle(VbColor.onSurfaceVariant),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined, size: 22),
                    activeIcon: Icon(Icons.home_outlined, size: 22),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_outlined, size: 22),
                    activeIcon: Icon(Icons.grid_view_outlined, size: 22),
                    label: 'Lessons',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.analytics_outlined, size: 22),
                    activeIcon: Icon(Icons.analytics_outlined, size: 22),
                    label: 'Progress',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history_toggle_off, size: 22),
                    activeIcon: Icon(Icons.history_toggle_off, size: 22),
                    label: 'History',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline, size: 22),
                    activeIcon: Icon(Icons.person_outline, size: 22),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
