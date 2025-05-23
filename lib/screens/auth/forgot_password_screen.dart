import 'package:email_application/screens/auth/reset_password_otp_screen.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/config/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;

  InputDecoration _themedInputDecoration(String label, IconData iconData) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.secondaryText),
      prefixIcon: Icon(iconData, color: AppColors.secondaryText),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: AppColors.primary),
    );
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

  Future<void> _sendResetOtp() async {
    if (!_formKey.currentState!.validate()) {
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
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP sent to $phoneNumber')));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ResetPasswordOtpScreen(
                    verificationId: verificationId,
                    phoneNumber: e164PhoneNumber,
                  ),
            ),
          );
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
        print("OTP auto-retrieval timed out: $verificationId");
      },
    );
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reset Your Password',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter your registered phone number. We will send an OTP to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: _themedInputDecoration(
                    'Phone Number',
                    Icons.phone_android_rounded,
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
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                    : ElevatedButton(
                      onPressed: _sendResetOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Send OTP'),
                    ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
