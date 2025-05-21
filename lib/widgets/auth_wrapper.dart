import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/screens/auth/login_screen.dart';
import 'package:email_application/screens/main_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    print('AuthWrapper build: User from Provider.of<User?> - $user');

    if (user == null) {
      return const LoginScreen();
    } else {
      return const MainScreen();
    }
  }
}
