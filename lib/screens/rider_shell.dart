import 'package:flutter/material.dart';
import 'messages_screen.dart';
import 'rider_earnings_screen.dart';
import 'rider_home_screen.dart';
import 'rider_profile_screen.dart';
import '../widgets/rider_bottom_nav_bar.dart';

class RiderShell extends StatefulWidget {
  const RiderShell({super.key});

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  static const _bgColor = Color(0xFFEFF1E4);

  int _currentIndex = 0;

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 1:
        return const RiderEarningsScreen();
      case 2:
        return const MessagesScreen(role: MessagingRole.rider);
      case 3:
        return const RiderProfileScreen();
      default:
        return const RiderHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _buildScreen(),
      bottomNavigationBar: RiderBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}