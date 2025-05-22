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

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Vui lòng đăng nhập lại để thực hiện thao tác này.';
      }
      if (user.email == null) {
        return 'Không tìm thấy thông tin email để xác thực lại.';
      }

      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);
      print('AuthService: Đổi mật khẩu thành công cho ${user.email}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('AuthService ChangePassword Error Code: ${e.code}');
      if (e.code == 'wrong-password') {
        return 'Mật khẩu hiện tại không đúng. Vui lòng thử lại.';
      } else if (e.code == 'weak-password') {
        return 'Mật khẩu mới quá yếu. Vui lòng chọn mật khẩu mạnh hơn (ít nhất 6 ký tự).';
      } else if (e.code == 'user-mismatch' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'ERROR_INVALID_CREDENTIAL') {
        return 'Mật khẩu hiện tại không đúng. Vui lòng thử lại.';
      } else if (e.code == 'requires-recent-login') {
        return 'Phiên đăng nhập của bạn đã cũ. Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu.';
      }
      print('AuthService ChangePassword Firebase Error: ${e.message}');
      return 'Lỗi khi đổi mật khẩu: ${e.message} (Mã: ${e.code})';
    } catch (e) {
      print('AuthService ChangePassword Unknown Error: ${e.toString()}');
      return 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại sau.';
    }
  }
}
