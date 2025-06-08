import 'package:email_application/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RegistrationStep {
  phoneInput,
  otpInput,
  personalInfoInput,
  emailPasswordInput,
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  RegistrationStep _currentStepEnum = RegistrationStep.phoneInput;
  final PageController _pageController = PageController();

  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _personalInfoFormKey = GlobalKey<FormState>();
  final _emailPasswordFormKey = GlobalKey<FormState>();

  final _phoneNumberController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _dobController = TextEditingController();

  late FocusNode _phoneFocusNode;
  late FocusNode _otpFocusNode;
  late FocusNode _displayNameFocusNode;
  late FocusNode _dobFocusNode;
  late FocusNode _genderFocusNode;
  late FocusNode _emailUsernameFocusNode;
  late FocusNode _passwordFocusNode;
  late FocusNode _confirmPasswordFocusNode;

  String? _verificationId;
  String _verifiedPhoneNumberForDisplay = '';
  String _e164VerifiedPhoneNumber = '';

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode = FocusNode()..addListener(_onFocusChange);
    _otpFocusNode = FocusNode()..addListener(_onFocusChange);
    _displayNameFocusNode = FocusNode()..addListener(_onFocusChange);
    _dobFocusNode = FocusNode()..addListener(_onFocusChange);
    _genderFocusNode = FocusNode()..addListener(_onFocusChange);
    _emailUsernameFocusNode = FocusNode()..addListener(_onFocusChange);
    _passwordFocusNode = FocusNode()..addListener(_onFocusChange);
    _confirmPasswordFocusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneNumberController.dispose();
    _otpController.dispose();
    _emailUsernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _dobController.dispose();

    _phoneFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.dispose();
    _otpFocusNode.removeListener(_onFocusChange);
    _otpFocusNode.dispose();
    _displayNameFocusNode.removeListener(_onFocusChange);
    _displayNameFocusNode.dispose();
    _dobFocusNode.removeListener(_onFocusChange);
    _dobFocusNode.dispose();
    _genderFocusNode.removeListener(_onFocusChange);
    _genderFocusNode.dispose();
    _emailUsernameFocusNode.removeListener(_onFocusChange);
    _emailUsernameFocusNode.dispose();
    _passwordFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.removeListener(_onFocusChange);
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _moveToPage(int pageIndex) {
    if (mounted) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      setState(() {
        _currentStepEnum = RegistrationStep.values[pageIndex];
      });
    }
  }

  void _handleBackPress() {
    if (_isLoading) return;
    if (_pageController.page == 0) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } else {
      _moveToPage(_pageController.page!.toInt() - 1);
    }
  }

  String _formatPhoneNumberToE164(String phoneNumber) {
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    if (cleanedNumber.startsWith('0')) {
      return '+84${cleanedNumber.substring(1)}';
    }
    if (!cleanedNumber.startsWith('+')) {
      if (cleanedNumber.length == 9 && !cleanedNumber.startsWith('+')) {
        return '+84$cleanedNumber';
      }
      return '+$cleanedNumber';
    }
    return cleanedNumber;
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final authService = Provider.of<AuthService>(context, listen: false);

    _verifiedPhoneNumberForDisplay = _phoneNumberController.text.trim();
    _e164VerifiedPhoneNumber = _formatPhoneNumberToE164(
      _verifiedPhoneNumberForDisplay,
    );

    await authService.sendOtp(
      phoneNumber: _e164VerifiedPhoneNumber,
      codeSent: (verificationId, resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          _moveToPage(RegistrationStep.otpInput.index);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OTP has been sent to $_verifiedPhoneNumberForDisplay',
              ),
            ),
          );
        }
      },
      verificationFailed: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          String errorMessage =
              'Failed to send OTP: ${e.message ?? "Please try again."}';
          if (e.message != null &&
              e.message!.toLowerCase().contains(
                'we have blocked all requests from this device due to unusual activity',
              )) {
            errorMessage =
                'Failed to send OTP: Firebase has blocked requests from this device due to unusual activity. Please try again later or use a different device.';
          } else if (e.code == 'app-not-authorized' ||
              (e.message != null &&
                  e.message!.toLowerCase().contains('play_integrity_token'))) {
            errorMessage =
                'Failed to send OTP: App not authorized. Please check Package Name and SHA-1/SHA-256 configuration in Firebase Console.';
          } else if (e.code == 'invalid-phone-number') {
            errorMessage =
                'Failed to send OTP: Invalid phone number ($_e164VerifiedPhoneNumber). Please check again.';
          } else if (e.code == 'too-many-requests') {
            errorMessage =
                'Failed to send OTP: Too many requests. Please try again later.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 7),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (mounted) {
          print(
            "OTP auto-retrieval timed out. Verification ID: $verificationId",
          );
        }
      },
    );
  }

  Future<void> _verifyOtpAndProceed() async {
    if (!_otpFormKey.currentState!.validate()) return;
    if (_verificationId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Verification ID is missing. Please restart the phone number step.',
            ),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _isLoading = true);

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _otpController.text.trim(),
    );

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      User? firebaseUser = userCredential.user;

      if (firebaseUser == null)
        throw Exception("User is null after successful OTP sign-in.");

      print(
        "OTP verified successfully. User signed in via phone: ${firebaseUser.uid}",
      );

      bool emailProviderLinked = firebaseUser.providerData.any(
        (userInfo) => userInfo.providerId == EmailAuthProvider.PROVIDER_ID,
      );

      if (emailProviderLinked) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This phone number is already fully registered. Please log in.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          if (Navigator.canPop(context)) {
            Navigator.of(context).popUntil(
              (route) => route.isFirst || route.settings.name == '/login',
            );
            if (ModalRoute.of(context)?.settings.name == '/register' &&
                Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            if (ModalRoute.of(context)?.isFirst == true &&
                ModalRoute.of(context)?.settings.name != '/login') {
              Navigator.pushReplacementNamed(context, '/login');
            }
          } else {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _moveToPage(RegistrationStep.personalInfoInput.index);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'OTP verification successful! Continue registration.',
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = "Invalid OTP or session expired.";
        if (e.code == 'invalid-verification-code')
          errorMessage = 'Incorrect OTP. Please try again.';
        else if (e.code == 'session-expired')
          errorMessage = 'OTP session expired. Please resend OTP.';
        else
          errorMessage = 'OTP verification failed: ${e.message ?? e.code}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An unexpected error occurred during OTP verification: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  void _proceedToEmailPassword() {
    if (!_personalInfoFormKey.currentState!.validate()) return;
    if (mounted) {
      _moveToPage(RegistrationStep.emailPasswordInput.index);
    }
  }

  Future<void> _completeRegistration() async {
    if (!_emailPasswordFormKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: OTP session not found. Please restart from the beginning.',
            ),
          ),
        );
        setState(() => _isLoading = false);
        _moveToPage(RegistrationStep.phoneInput.index);
      }
      return;
    }

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final String emailUsername = _emailUsernameController.text.trim();
    final String emailToLink = '$emailUsername@tvamail.com';
    final String password = _passwordController.text;
    final String displayName = _displayNameController.text.trim();

    try {
      final List<String> signInMethods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(emailToLink);
      if (signInMethods.isNotEmpty) {
        bool linkedToCurrentUser = currentUser.providerData.any(
          (info) => info.email == emailToLink,
        );
        if (!linkedToCurrentUser) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Email address "$emailToLink" is already in use by another account.',
                ),
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
        print(
          "Email $emailToLink is already part of this user's providers or matches user.email. No new link needed.",
        );
      } else {
        AuthCredential emailCredential = EmailAuthProvider.credential(
          email: emailToLink,
          password: password,
        );
        await currentUser.linkWithCredential(emailCredential);
        print(
          "Email ($emailToLink) and password successfully linked to user ${currentUser.uid}",
        );
        await currentUser.reload();
      }

      final User userForProfile = FirebaseAuth.instance.currentUser!;

      await firestoreService.createUserProfile(
        user: userForProfile,
        phoneNumber: _e164VerifiedPhoneNumber,
        customEmail: emailToLink,
        displayName: displayName,
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth,
        isProfileFullyCompleted: true,
      );

      if (userForProfile.displayName == null ||
          userForProfile.displayName != displayName) {
        await userForProfile.updateDisplayName(displayName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration and information update successful!'),
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage =
            'Registration completion failed. ${e.message ?? e.code}';
        if (e.code == 'email-already-in-use') {
          errorMessage =
              'This email ($emailToLink) is already in use by another account.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak.';
        } else if (e.code == 'provider-already-linked') {
          errorMessage = 'This email is already linked to your account.';
        } else if (e.code == 'credential-already-in-use' &&
            e.message != null &&
            e.message!.toLowerCase().contains('email')) {
          errorMessage =
              'Email ($emailToLink) is already in use by another Firebase account.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _themedInputDecoration(
    String label,
    String hint,
    IconData iconData,
    bool isFocused,
    ThemeData theme,
  ) {
    final Color currentIconColor =
        isFocused ? theme.primaryColor : theme.textTheme.bodyMedium!.color!;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(iconData, color: currentIconColor),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.primaryColor, width: 2.0),
      ),
      labelStyle: theme.textTheme.bodyMedium,
      floatingLabelStyle: TextStyle(color: theme.primaryColor),
    );
  }

  Widget _buildPhoneInputPage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Form(
        key: _phoneFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Step 1: Enter Phone Number",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _phoneNumberController,
              focusNode: _phoneFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Phone Number',
                'E.g., 0901234567 or +84901234567',
                Icons.phone_android_rounded,
                _phoneFocusNode.hasFocus,
                theme,
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter your phone number.';
                if (!RegExp(
                  r'^(?:\+?[1-9]\d{7,14}|0\d{9,10})$',
                ).hasMatch(value.replaceAll(RegExp(r'\s+|-|\(|\)'), '')))
                  return 'Invalid phone number format.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
                : ElevatedButton(
                  onPressed: _sendOtp,
                  child: const Text('Send OTP'),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInputPage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Form(
        key: _otpFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Step 2: Verify OTP",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Enter the OTP sent to\n$_verifiedPhoneNumberForDisplay",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'OTP Code (6 digits)',
                '******',
                Icons.sms_failed_outlined,
                _otpFocusNode.hasFocus,
                theme,
              ).copyWith(counterText: ""),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter the OTP.';
                if (value.length != 6) return 'OTP must be 6 digits.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
                : ElevatedButton(
                  onPressed: _verifyOtpAndProceed,
                  child: const Text('Verify OTP & Continue'),
                ),
            TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : () => _moveToPage(RegistrationStep.phoneInput.index),
              child: const Text("Back to Phone Input"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoInputPage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Form(
        key: _personalInfoFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Step 3: Personal Information",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _displayNameController,
              focusNode: _displayNameFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Full Name',
                'John Doe',
                Icons.person_outline_rounded,
                _displayNameFocusNode.hasFocus,
                theme,
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter your full name.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              focusNode: _genderFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Gender',
                '',
                Icons.wc_rounded,
                _genderFocusNode.hasFocus,
                theme,
              ).copyWith(
                hintText: 'Select Gender',
                hintStyle: theme.textTheme.bodyMedium,
              ),
              value: _selectedGender,
              items:
                  ['Nam', 'Nữ', 'Khác']
                      .map(
                        (label) => DropdownMenuItem(
                          value: label,
                          child: Text(
                            label == 'Nam'
                                ? 'Male'
                                : label == 'Nữ'
                                ? 'Female'
                                : 'Other',
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
              validator:
                  (value) =>
                      value == null ? 'Please select your gender.' : null,
              iconEnabledColor:
                  _genderFocusNode.hasFocus
                      ? theme.primaryColor
                      : theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobController,
              focusNode: _dobFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Date of Birth',
                'Tap to select date',
                Icons.calendar_today_rounded,
                _dobFocusNode.hasFocus,
                theme,
              ),
              readOnly: true,
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate:
                      _selectedDateOfBirth ??
                      DateTime.now().subtract(const Duration(days: 365 * 18)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now().subtract(
                    const Duration(days: 365 * 5),
                  ),
                  locale: const Locale('vi', 'VN'),
                  builder: (context, child) {
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(
                          primary: AppColors.primary,
                          onPrimary: AppColors.lightOnPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null && pickedDate != _selectedDateOfBirth) {
                  setState(() {
                    _selectedDateOfBirth = pickedDate;
                    _dobController.text = DateFormat(
                      'dd/MM/yyyy',
                    ).format(pickedDate);
                  });
                }
              },
              validator:
                  (value) =>
                      _selectedDateOfBirth == null
                          ? 'Please select your date of birth.'
                          : null,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
                : ElevatedButton(
                  onPressed: _proceedToEmailPassword,
                  child: const Text('Continue'),
                ),
            TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : () => _moveToPage(RegistrationStep.otpInput.index),
              child: const Text("Back to OTP Input"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailPasswordInputPage() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Form(
        key: _emailPasswordFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Step 4: Create Email & Password",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailUsernameController,
              focusNode: _emailUsernameFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Email Username',
                'e.g., your.name',
                Icons.alternate_email_rounded,
                _emailUsernameFocusNode.hasFocus,
                theme,
              ).copyWith(suffixText: "@tvamail.com"),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please choose a username.';
                if (value.contains('@') || value.contains(' '))
                  return 'Username is invalid (no @ or spaces).';
                if (value.length < 3)
                  return 'Username must be at least 3 characters.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Password',
                '******',
                Icons.lock_outline_rounded,
                _passwordFocusNode.hasFocus,
                theme,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color:
                        _passwordFocusNode.hasFocus
                            ? theme.primaryColor
                            : theme.textTheme.bodyMedium?.color,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter a password.';
                if (value.length < 6)
                  return 'Password must be at least 6 characters.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _themedInputDecoration(
                'Confirm Password',
                '******',
                Icons.lock_person_outlined,
                _confirmPasswordFocusNode.hasFocus,
                theme,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color:
                        _confirmPasswordFocusNode.hasFocus
                            ? theme.primaryColor
                            : theme.textTheme.bodyMedium?.color,
                  ),
                  onPressed:
                      () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                ),
              ),
              obscureText: _obscureConfirmPassword,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please confirm your password.';
                if (value != _passwordController.text)
                  return 'Passwords do not match.';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              "Verified Phone: $_verifiedPhoneNumberForDisplay",
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              "Full Name: ${_displayNameController.text}",
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                )
                : ElevatedButton(
                  onPressed: _completeRegistration,
                  child: const Text('Complete Registration'),
                ),
            TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : () =>
                          _moveToPage(RegistrationStep.personalInfoInput.index),
              child: const Text("Back to Personal Info"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'Create New Account';
    switch (_currentStepEnum) {
      case RegistrationStep.phoneInput:
        appBarTitle = 'Step 1: Phone Number';
        break;
      case RegistrationStep.otpInput:
        appBarTitle = 'Step 2: Verify OTP';
        break;
      case RegistrationStep.personalInfoInput:
        appBarTitle = 'Step 3: Personal Information';
        break;
      case RegistrationStep.emailPasswordInput:
        appBarTitle = 'Step 4: Create Email & Password';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBackPress,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPhoneInputPage(),
            _buildOtpInputPage(),
            _buildPersonalInfoInputPage(),
            _buildEmailPasswordInputPage(),
          ],
        ),
      ),
    );
  }
}
