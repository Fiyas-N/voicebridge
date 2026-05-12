import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, size: 22),
                  activeIcon: Icon(Icons.home_filled, size: 22),
                  label: 'HOME',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined, size: 22),
                  activeIcon: Icon(Icons.grid_view_rounded, size: 22),
                  label: 'LESSONS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined, size: 22),
                  activeIcon: Icon(Icons.analytics_rounded, size: 22),
                  label: 'DATA',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_toggle_off, size: 22),
                  activeIcon: Icon(Icons.history_rounded, size: 22),
                  label: 'LOGS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline, size: 22),
                  activeIcon: Icon(Icons.person, size: 22),
                  label: 'ME',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
