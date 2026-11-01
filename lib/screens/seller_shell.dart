import 'package:flutter/material.dart';
import 'messages_screen.dart';
import 'seller_dashboard_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_products_screen.dart';
import 'seller_profile_screen.dart';
import '../widgets/seller_bottom_nav_bar.dart';

class SellerShell extends StatefulWidget {
  const SellerShell({super.key});

  static const dashboardTab = 0;
  static const productsTab = 1;
  static const ordersTab = 2;
  static const chatTab = 3;
  static const profileTab = 4;

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  static const _bgColor = Color(0xFFEFF1E4);

  int _currentIndex = SellerShell.dashboardTab;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  Widget _buildScreen() {
    switch (_currentIndex) {
      case SellerShell.productsTab:
        return const SellerProductsScreen();
      case SellerShell.ordersTab:
        return const SellerOrdersScreen(showBackButton: false);
      case SellerShell.chatTab:
        return const MessagesScreen(role: MessagingRole.seller);
      case SellerShell.profileTab:
        return const SellerProfileScreen();
      case SellerShell.dashboardTab:
      default:
        return SellerDashboardScreen(onOpenTab: _goToTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _buildScreen(),
      bottomNavigationBar: SellerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
      ),
    );
  }
}