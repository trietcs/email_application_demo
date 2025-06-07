import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailPasswordFormKey = GlobalKey<FormState>();
  final _phoneOtpFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _otpController = TextEditingController();

  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  late FocusNode _phoneNumberFocusNode;
  late FocusNode _otpFocusNode;

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _showPhoneOtpLogin = false;

  String? _phoneVerificationId;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode()..addListener(_onFocusChange);
    _passwordFocusNode = FocusNode()..addListener(_onFocusChange);
    _phoneNumberFocusNode = FocusNode()..addListener(_onFocusChange);
    _otpFocusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearFormsAndErrors() {
    _emailPasswordFormKey.currentState?.reset();
    _phoneOtpFormKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
    _phoneNumberController.clear();
    _otpController.clear();
    _otpSent = false;
    _phoneVerificationId = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    _otpController.dispose();

    _emailFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.dispose();
    _phoneNumberFocusNode.removeListener(_onFocusChange);
    _phoneNumberFocusNode.dispose();
    _otpFocusNode.removeListener(_onFocusChange);
    _otpFocusNode.dispose();
    super.dispose();
  }

  String _formatPhoneNumberToE164(String phoneNumber) {
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    if (cleanedNumber.startsWith('0')) {
      return '+84${cleanedNumber.substring(1)}';
    }
    if (!cleanedNumber.startsWith('+')) {
      if (cleanedNumber.length == 9) {
        return '+84$cleanedNumber';
      }
      return '+$cleanedNumber';
    }
    return cleanedNumber;
  }

  Future<void> _loginWithEmailPassword() async {
    if (!_emailPasswordFormKey.currentState!.validate()) return;

    if (mounted) setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed. Please check your credentials.';
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          errorMessage = 'Incorrect email or password.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email format.';
        } else if (e.code == 'invalid-credential') {
          errorMessage = 'Incorrect email or password.';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendLoginOtp() async {
    if (!_phoneOtpFormKey.currentState!.validate()) return;
    if (_phoneNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number.')),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final String phoneNumber = _phoneNumberController.text.trim();
    final String e164PhoneNumber = _formatPhoneNumberToE164(phoneNumber);

    await authService.sendOtp(
      phoneNumber: e164PhoneNumber,
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _phoneVerificationId = verificationId;
            _otpSent = true;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP sent to $phoneNumber')));
        }
      },
      verificationFailed: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send OTP: ${e.message}')),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print("Login OTP auto-retrieval timed out: $verificationId");
      },
    );
  }

  Future<void> _loginWithPhoneOtp() async {
    if (_otpController.text.isEmpty || _otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP.')),
      );
      return;
    }
    if (_phoneVerificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP not sent yet or session expired.')),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signInWithPhoneOtp(
        verificationId: _phoneVerificationId!,
        smsCode: _otpController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'OTP Login failed.';
        if (e.code == 'invalid-verification-code') {
          errorMessage = 'Incorrect OTP.';
        } else if (e.code == 'session-expired') {
          errorMessage = 'OTP session expired. Please resend OTP.';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _themedInputDecoration(
    String label,
    String hint,
    IconData iconData,
    bool isFocused,
    ThemeData theme, {
    Widget? suffixIcon,
  }) {
    final Color iconColor =
        isFocused ? theme.primaryColor : theme.textTheme.bodyMedium!.color!;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(iconData, color: iconColor),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.primaryColor, width: 2.0),
      ),
      labelStyle: theme.textTheme.bodyMedium,
      floatingLabelStyle: TextStyle(color: theme.primaryColor),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TVA Mail Login'), elevation: 1),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child:
              _showPhoneOtpLogin
                  ? _buildPhoneOtpForm()
                  : _buildEmailPasswordForm(),
        ),
      ),
    );
  }

  Widget _buildEmailPasswordForm() {
    final theme = Theme.of(context);
    return Form(
      key: _emailPasswordFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/images/app_logo.png', height: 80, width: 80),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            decoration: _themedInputDecoration(
              'Username or Email',
              'Enter your username',
              Icons.email_outlined,
              _emailFocusNode.hasFocus,
              theme,
            ),
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your username or email.';
              }
              if (value.contains('@') && !value.endsWith('@tvamail.com')) {
                return 'Email must end with @tvamail.com';
              }
              if (value.contains(' ')) {
                return 'Username/email cannot contain spaces.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            decoration: _themedInputDecoration(
              'Password',
              '******',
              Icons.lock_outline_rounded,
              _passwordFocusNode.hasFocus,
              theme,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color:
                      _passwordFocusNode.hasFocus
                          ? theme.primaryColor
                          : theme.textTheme.bodyMedium?.color,
                ),
                onPressed: () {
                  if (mounted) {
                    setState(() => _obscurePassword = !_obscurePassword);
                  }
                },
              ),
            ),
            obscureText: _obscurePassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/forgot-password');
                },
                child: const Text('Forgot Password?'),
              ),
            ),
          ),
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              )
              : ElevatedButton(
                onPressed: _loginWithEmailPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Login'),
              ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _showPhoneOtpLogin = true;
                  _clearFormsAndErrors();
                });
              }
            },
            child: const Text('Login with Phone Number & OTP'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            child: const Text('No account? Register Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneOtpForm() {
    final theme = Theme.of(context);
    return Form(
      key: _phoneOtpFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/images/app_logo.png', height: 80, width: 80),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneNumberController,
            focusNode: _phoneNumberFocusNode,
            decoration: _themedInputDecoration(
              'Phone Number',
              'Enter your phone number',
              Icons.phone_android_rounded,
              _phoneNumberFocusNode.hasFocus,
              theme,
            ),
            keyboardType: TextInputType.phone,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number.';
              }
              if (!RegExp(
                r'^(?:\+?[1-9]\d{7,14}|0\d{9,10})$',
              ).hasMatch(value.replaceAll(RegExp(r'\s+|-|\(|\)'), ''))) {
                return 'Invalid phone number format.';
              }
              return null;
            },
            enabled: !_otpSent,
          ),
          const SizedBox(height: 16),
          if (_otpSent)
            TextFormField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              decoration: _themedInputDecoration(
                'OTP Code (6 digits)',
                'Enter OTP',
                Icons.sms_outlined,
                _otpFocusNode.hasFocus,
                theme,
              ).copyWith(counterText: ""),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the OTP.';
                }
                if (value.length != 6) {
                  return 'OTP must be 6 digits.';
                }
                return null;
              },
            ),
          const SizedBox(height: 24),
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              )
              : ElevatedButton(
                onPressed: _otpSent ? _loginWithPhoneOtp : _sendLoginOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(_otpSent ? 'Login with OTP' : 'Send OTP'),
              ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _showPhoneOtpLogin = false;
                  _clearFormsAndErrors();
                });
              }
            },
            child: const Text('Login with Email & Password'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            child: const Text('No account? Register Now'),
          ),
        ],
      ),
    );
  }
}
