import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_application/screens/auth/login_screen.dart';
import 'package:email_application/screens/auth/register_screen.dart';
import 'package:email_application/screens/emails/compose_email_screen.dart';
import 'package:email_application/screens/main_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/widgets/auth_wrapper.dart';
import 'package:email_application/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        // Cung cấp AuthService
        Provider<AuthService>(create: (_) => AuthService()),
        // Cung cấp FirestoreService
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        // Cung cấp Stream trạng thái người dùng
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVA Email',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthWrapper(),
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
