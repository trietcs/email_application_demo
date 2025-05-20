import 'package:email_application/screens/auth/login_screen.dart';
import 'package:email_application/screens/auth/register_screen.dart';
import 'package:email_application/screens/main_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVA Email',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/main',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/profile': (context) => const ViewProfileScreen(),
      },
    );
  }
}
