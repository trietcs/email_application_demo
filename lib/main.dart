import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:email_application/firebase_options.dart';
import 'package:email_application/screens/auth/login_screen.dart';
import 'package:email_application/screens/auth/register_screen.dart';
import 'package:email_application/screens/main_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVA Email',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/profile': (context) => const ViewProfileScreen(),
        '/compose': (context) => const ComposeEmailScreen(),
      },
    );
  }
}
