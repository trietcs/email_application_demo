import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _login() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.signIn(
      phoneNumber: _phoneNumberController.text,
      password: _passwordController.text,
    );
    setState(() => _isLoading = false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập thất bại. Số điện thoại hoặc mật khẩu không đúng.')),
      );
    }
  }
}

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FlutterLogo(size: 100),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(value)) {
                      return 'Số điện thoại không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        child: const Text('Đăng nhập'),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}