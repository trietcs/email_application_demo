import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:email_application/widgets/auth_wrapper.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const ResetPasswordOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _otpVerified = false;

  InputDecoration _themedInputDecoration(
    String label,
    IconData iconData,
    ThemeData theme, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: theme.textTheme.bodyMedium,
      prefixIcon: Icon(iconData, color: theme.textTheme.bodyMedium?.color),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: theme.primaryColor),
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _verifyOtpAndPreparePasswordReset() async {
    if (_otpController.text.isEmpty || _otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP.')),
      );
      return;
    }
    if (mounted) setState(() => _isLoading = true);

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: _otpController.text.trim(),
    );

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _otpVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'OTP verified successfully! Please set your new password.',
              ),
            ),
          );
        }
      } else {
        throw Exception("User not found after OTP verification.");
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verification failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (mounted) setState(() => _isLoading = true);

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session expired or user not found. Please try again.',
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    try {
      await currentUser.updatePassword(_newPasswordController.text.trim());

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully!')),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otpVerified ? 'Set New Password' : 'Verify OTP'),
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: _otpVerified ? _buildNewPasswordForm() : _buildOtpForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpForm() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify Your Phone Number',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'An OTP has been sent to ${widget.phoneNumber}.\nPlease enter the 6-digit code below.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _otpController,
          decoration: _themedInputDecoration(
            'OTP Code (6 digits)',
            Icons.sms_outlined,
            theme,
          ).copyWith(counterText: ""),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
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
              onPressed: _verifyOtpAndPreparePasswordReset,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Verify OTP'),
            ),
      ],
    );
  }

  Widget _buildNewPasswordForm() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create New Password',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _newPasswordController,
          decoration: _themedInputDecoration(
            'New Password',
            Icons.lock_outline_rounded,
            theme,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                color: theme.textTheme.bodyMedium?.color,
              ),
              onPressed:
                  () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
            ),
          ),
          obscureText: _obscureNewPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a new password.';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: _themedInputDecoration(
            'Confirm New Password',
            Icons.lock_person_rounded,
            theme,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: theme.textTheme.bodyMedium?.color,
              ),
              onPressed:
                  () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your new password.';
            }
            if (value != _newPasswordController.text) {
              return 'Passwords do not match.';
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
              onPressed: _setNewPassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Set New Password'),
            ),
      ],
    );
  }
}
