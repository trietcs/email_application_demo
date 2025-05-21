import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> signUp({
    required String phoneNumber,
    required String password,
    String? displayName,
  }) async {
    try {
      String email = '$phoneNumber@tvamail.com';
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('SignUp Error: Mật khẩu quá yếu.');
      } else if (e.code == 'email-already-in-use') {
        print('SignUp Error: Số điện thoại này đã được sử dụng.');
      } else if (e.code == 'invalid-email') {
        print('SignUp Error: Số điện thoại không hợp lệ.');
      } else {
        print('SignUp Error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('SignUp Error: Lỗi không xác định - ${e.toString()}');
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
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('SignIn Error: Không tìm thấy người dùng với số điện thoại này.');
      } else if (e.code == 'wrong-password') {
        print('SignIn Error: Sai mật khẩu.');
      } else if (e.code == 'invalid-email') {
        print('SignIn Error: Số điện thoại không hợp lệ.');
      } else if (e.code == 'invalid-credential') {
        print('SignIn Error: Thông tin đăng nhập không hợp lệ.');
      } else {
        print('SignIn Error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('SignIn Error: Lỗi không xác định - ${e.toString()}');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('SignOut Error: Lỗi khi đăng xuất - ${e.toString()}');
    }
  }
}
