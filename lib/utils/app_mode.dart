import 'package:flutter/material.dart';

enum AppRole { buyer, seller, rider }

final ValueNotifier<AppRole?> activeRoleNotifier = ValueNotifier<AppRole?>(
  null,
);

extension AppRoleStyle on AppRole {
  String get label => switch (this) {
    AppRole.buyer => 'Buyer',
    AppRole.seller => 'Seller',
    AppRole.rider => 'Rider',
  };

  String get tagline => switch (this) {
    AppRole.buyer => 'Shop fresh produce',
    AppRole.seller => 'Manage your farm store',
    AppRole.rider => 'Deliver orders',
  };

  IconData get icon => switch (this) {
    AppRole.buyer => Icons.shopping_basket_outlined,
    AppRole.seller => Icons.eco_outlined,
    AppRole.rider => Icons.two_wheeler_outlined,
  };

  Color get color => switch (this) {
    AppRole.buyer => const Color(0xFF1F3D2B),
    AppRole.seller => const Color(0xFFE0A63A),
    AppRole.rider => const Color(0xFF1D5D9B),
  };

  Color get onColor =>
      this == AppRole.seller ? const Color(0xFF1F3D2B) : Colors.white;
}