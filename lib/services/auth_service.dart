import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();
  Stream<User?> get userChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(String verificationId) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        print('AuthService: Phone verification completed automatically.');
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: timeout,
    );
  }

  Future<User?> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      print('AuthService: Email/Password registration successful for $email');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print(
        'AuthService: Email/Password registration error: ${e.code} - ${e.message}',
      );
      throw e;
    } catch (e) {
      print(
        'AuthService: Email/Password registration unknown error: ${e.toString()}',
      );
      throw e;
    }
  }

  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      String emailToSignIn = email.trim();
      if (!emailToSignIn.contains('@')) {
        emailToSignIn = '$emailToSignIn@tvamail.com';
      } else if (!emailToSignIn.endsWith('@tvamail.com')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Invalid email format. Email must end with @tvamail.com.',
        );
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailToSignIn,
        password: password,
      );
      print(
        'AuthService: Email/Password sign-in successful for $emailToSignIn',
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print(
        'AuthService Email/Password Sign-in FirebaseAuthException: Code: ${e.code}, Message: ${e.message}',
      );
      throw e;
    } catch (e) {
      print(
        'AuthService Email/Password Sign-in General Error: ${e.toString()}',
      );
      throw Exception(
        'An unexpected error occurred during email/password sign-in.',
      );
    }
  }

  Future<User?> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      print(
        'AuthService: Phone OTP sign-in successful for UID: ${userCredential.user?.uid}',
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print(
        'AuthService Phone OTP Sign-in FirebaseAuthException: Code: ${e.code}, Message: ${e.message}',
      );
      throw e;
    } catch (e) {
      print('AuthService Phone OTP Sign-in General Error: ${e.toString()}');
      throw Exception('An unexpected error occurred during phone OTP sign-in.');
    }
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _auth.signOut();
        print(
          'AuthService: Sign-out successful for ${user.email ?? user.phoneNumber}',
        );
      } else {
        print('AuthService: No user to sign out.');
      }
    } catch (e) {
      print(
        'AuthService Sign-out Error: Error while signing out - ${e.toString()}',
      );
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Please log in again to perform this action.';
      }
      if (user.email == null) {
        return 'Email information not found for re-authentication.';
      }

      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      print('AuthService: Password changed successfully for ${user.email}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('AuthService ChangePassword Error Code: ${e.code}');
      if (e.code == 'wrong-password' ||
          e.code == 'user-mismatch' ||
          e.code == 'invalid-credential' ||
          e.code == 'ERROR_INVALID_CREDENTIAL') {
        return 'Incorrect current password. Please try again.';
      } else if (e.code == 'weak-password') {
        return 'New password is too weak. Please choose a stronger password (at least 6 characters).';
      } else if (e.code == 'requires-recent-login') {
        return 'Your session is old. Please sign out and sign in again before changing password.';
      }
      print('AuthService ChangePassword Firebase Error: ${e.message}');
      return 'Failed to change password: ${e.message ?? e.code}';
    } catch (e) {
      print('AuthService ChangePassword Unknown Error: ${e.toString()}');
      return 'An unexpected error occurred. Please try again later.';
    }
  }
}
