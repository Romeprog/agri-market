import 'package:firebase_auth/firebase_auth.dart';

const String kAdminEmail = 'agrimarket.support@gmail.com';

bool isAdminUser(User? user) {
  final email = user?.email?.trim().toLowerCase();
  return email != null && email == kAdminEmail;
}