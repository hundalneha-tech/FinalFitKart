// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'move_screen.dart';
import 'social_screen.dart';
import 'perks_screen.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';
import 'workout_session_screen.dart';
import '../services/workout_session_manager.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    MoveScreen(),
    SocialScreen(),
    PerksScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined),      activeIcon: Icon(Icons.home_rounded),         label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.directions_run),     activeIcon: Icon(Icons.directions_run),       label: 'Move'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline),     activeIcon: Icon(Icons.people_rounded),       label: 'Social'),
    BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined),activeIcon: Icon(Icons.local_offer_rounded), label: 'Perks'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline),     activeIcon: Icon(Icons.person_rounded),       label: 'Profile'),
  ];

  void _openSession() {
    final mgr = WorkoutSessionManager();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WorkoutSessionScreen(type: mgr.type)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      // Live session banner — shows on every tab when session is active
      ListenableBuilder(
        listenable: WorkoutSessionManager(),
        builder: (_, __) => LiveSessionBanner(onTap: _openSession)),
      Expanded(child: IndexedStack(index: _index, children: _screens)),
    ]),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.6))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.navInactive,
        selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500),
        items: _items,
      ),
    ),
  );
}
