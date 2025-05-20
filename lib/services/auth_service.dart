import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Placeholder for authentication methods (to be implemented in Day 2)
  Stream<User?> get user => _auth.authStateChanges();
}
