import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/nav_provider.dart';
import 'widgets/mindkawan_navbar.dart';

import 'screens/voice_buddy_screen.dart';
import 'screens/mood_stress_screen.dart';
import 'screens/academic_pressure_screen.dart';
import 'screens/relaxation_room_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = <Widget>[
    VoiceBuddyScreen(),
    MoodStressScreen(),
    AcademicPressureScreen(),
    RelaxationRoomScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Preserve each tab's state when switching
      body: SafeArea(
        child: FocusTraversalGroup(
          child: IndexedStack(index: index, children: _screens),
        ),
      ),
      // Capsule bottom navbar styled to match your AppBar
      bottomNavigationBar: const MindKawanNavBar(),
    );
  }
}
