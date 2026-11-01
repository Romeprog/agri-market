import 'package:agri_market/auth/auth_service.dart';
import 'package:agri_market/auth/login_or_register.dart';
import 'package:agri_market/firebase_options.dart';
import 'package:agri_market/screens/admin_dashboard_screen.dart';
import 'package:agri_market/screens/choose_account_screen.dart';
import 'package:agri_market/screens/home_screen.dart';
import 'package:agri_market/screens/rider_shell.dart';
import 'package:agri_market/screens/seller_shell.dart';
import 'package:agri_market/utils/admin_access.dart';
import 'package:agri_market/utils/app_mode.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'AgriMarket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Color(0xFF1F3D2B)),
      home: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final user = authSnapshot.data;
          if (user == null) {
            return const LoginOrRegister();
          }
          if (isAdminUser(user)) {
            return const AdminDashboardScreen();
          }
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final data = userSnapshot.data?.data();
              final isSellerOnly = data?['sellerOnly'] == true;
              final isRiderOnly = data?['riderOnly'] == true;
              final roles = <AppRole>[
                if (!isSellerOnly && !isRiderOnly) AppRole.buyer,
                if (data?['isSeller'] == true || isSellerOnly) AppRole.seller,
                if (data?['isRider'] == true || isRiderOnly) AppRole.rider,
              ];
              if (roles.isEmpty) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (roles.length == 1) {
                return switch (roles.first) {
                  AppRole.buyer => const HomeScreen(),
                  AppRole.seller => const SellerShell(),
                  AppRole.rider => const RiderShell(),
                };
              }
              return ValueListenableBuilder<AppRole?>(
                valueListenable: activeRoleNotifier,
                builder: (context, active, _) {
                  if (active == null || !roles.contains(active)) {
                    return ChooseAccountScreen(roles: roles);
                  }
                  return switch (active) {
                    AppRole.buyer => const HomeScreen(),
                    AppRole.seller => const SellerShell(),
                    AppRole.rider => const RiderShell(),
                  };
                },
              );
            },
          );
        },
      ),
    );
  }
}