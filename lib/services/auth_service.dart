import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signUp({
    required String phoneNumber,
    required String password,
    String? displayName,
  }) async {
    try {
      String email = '$phoneNumber@tvamail.com';
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null && displayName != null) {
        await userCredential.user!.updateDisplayName(displayName);
      }
      print('AuthService: SignUp successful for $email');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('AuthService SignUp Error: Mật khẩu quá yếu.');
      } else if (e.code == 'email-already-in-use') {
        print('AuthService SignUp Error: Số điện thoại này đã được sử dụng.');
      } else if (e.code == 'invalid-email') {
        print('AuthService SignUp Error: Số điện thoại không hợp lệ.');
      } else {
        print('AuthService SignUp Error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('AuthService SignUp Error: Lỗi không xác định - ${e.toString()}');
      return null;
    }
  }

  Future<User?> signIn({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      String email = '$phoneNumber@tvamail.com';
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('AuthService: SignIn successful for $email');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print(
          'AuthService SignIn Error: Không tìm thấy người dùng với số điện thoại này.',
        );
      } else if (e.code == 'wrong-password') {
        print('AuthService SignIn Error: Sai mật khẩu.');
      } else if (e.code == 'invalid-email') {
        print('AuthService SignIn Error: Số điện thoại không hợp lệ.');
      } else if (e.code == 'invalid-credential') {
        print('AuthService SignIn Error: Thông tin đăng nhập không hợp lệ.');
      } else {
        print('AuthService SignIn Error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('AuthService SignIn Error: Lỗi không xác định - ${e.toString()}');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _auth.signOut();
        print('AuthService: SignOut successful for ${user.email}');
      } else {
        print('AuthService: No user to sign out.');
      }
    } catch (e) {
      print('AuthService SignOut Error: Lỗi khi đăng xuất - ${e.toString()}');
    }
  }
}
