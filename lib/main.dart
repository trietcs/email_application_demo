import 'package:email_application/config/app_colors.dart';
import 'package:email_application/firebase_options.dart';
import 'package:email_application/screens/auth/forgot_password_screen.dart';
import 'package:email_application/screens/auth/login_screen.dart';
import 'package:email_application/screens/auth/register_screen.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/screens/main_screen.dart';
import 'package:email_application/screens/profile/view_profile_screen.dart';
import 'package:email_application/screens/settings/settings_screen.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/services/theme_notifier.dart';
import 'package:email_application/services/view_mode_notifier.dart';
import 'package:email_application/widgets/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => ViewModeNotifier()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.lightBackground,
      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightOnSurface,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(
          color: AppColors.lightOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: const CardTheme(
        color: AppColors.lightSurface,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lightSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightOnBackground, fontSize: 16),
        bodyMedium: TextStyle(
          color: AppColors.lightSecondaryText,
          fontSize: 14,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightOnBackground,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightOnBackground,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ).apply(
        bodyColor: AppColors.lightOnBackground,
        displayColor: AppColors.lightOnBackground,
      ),

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.lightOnPrimary,
        secondary: AppColors.accent,
        background: AppColors.lightBackground,
        onBackground: AppColors.lightOnBackground,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightOnSurface,
        error: AppColors.error,
        onError: Colors.white,
      ),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(
          color: AppColors.darkOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: const CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkOnBackground, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.darkSecondaryText, fontSize: 14),
        titleLarge: TextStyle(
          color: AppColors.darkOnBackground,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.darkOnBackground,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ).apply(
        bodyColor: AppColors.darkOnBackground,
        displayColor: AppColors.darkOnBackground,
      ),

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.darkOnPrimary,
        secondary: AppColors.accent,
        background: AppColors.darkBackground,
        onBackground: AppColors.darkOnBackground,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        error: AppColors.error,
        onError: Colors.white,
      ),
    );

    return MaterialApp(
      title: 'TVA Email',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeNotifier.themeMode,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('vi', '')],
      locale: const Locale('vi', 'VN'),

      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/profile': (context) => const ViewProfileScreen(),
        '/compose': (context) => const ComposeEmailScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
