import 'dart:io';
import 'package:email_application/screens/profile/edit_profile_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:email_application/config/app_colors.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final _changePasswordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmNewPassword = true;
  bool _isPasswordSectionExpanded = false;

  bool _isUploadingPhoto = false;
  File? _pickedImageFile;
  String? _displayedPhotoUrl;

  @override
  void initState() {
    super.initState();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _displayedPhotoUrl = currentUser.photoURL;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDisplayedPhotoUrlFromProvider();
    });
  }

  void _updateDisplayedPhotoUrlFromProvider() {
    if (mounted) {
      final userFromProvider = Provider.of<User?>(context, listen: false);
      if (userFromProvider != null &&
          _displayedPhotoUrl != userFromProvider.photoURL) {
        if (_pickedImageFile == null) {
          setState(() {
            _displayedPhotoUrl = userFromProvider.photoURL;
          });
        }
      } else if (userFromProvider == null && _displayedPhotoUrl != null) {
        setState(() {
          _displayedPhotoUrl = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingPhoto) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedImage != null) {
        if (mounted) {
          setState(() {
            _pickedImageFile = File(pickedImage.path);
          });
          await _uploadProfilePicture();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_pickedImageFile == null) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _isUploadingPhoto = true);

    try {
      final String fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(user.uid)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(_pickedImageFile!);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await user.reload();

      final String? latestPhotoUrl =
          FirebaseAuth.instance.currentUser?.photoURL;

      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      await firestoreService.updateUserProfile(
        user.uid,
        photoURL: latestPhotoUrl ?? downloadUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
          ),
        );
        setState(() {
          _pickedImageFile = null;
          _displayedPhotoUrl = latestPhotoUrl;
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile picture: ${e.message}'),
          ),
        );
        setState(() => _pickedImageFile = null);
      }
      print("Error uploading profile picture: $e");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
          ),
        );
        setState(() => _pickedImageFile = null);
      }
      print("Unexpected error uploading profile picture: $e");
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        );
      },
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
      print('Logout error: $e');
    }
  }

  Future<void> _changePassword() async {
    if (!mounted) return;
    if (_changePasswordFormKey.currentState!.validate()) {
      if (_currentPasswordController.text == _newPasswordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'New password cannot be the same as the current password.',
              ),
            ),
          );
        }
        return;
      }

      if (_newPasswordController.text != _confirmNewPasswordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New password and confirmation do not match.'),
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _isChangingPassword = true);
      final authService = Provider.of<AuthService>(context, listen: false);
      final String? error = await authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _isChangingPassword = false);

      if (error == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully!')),
          );
        }
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
        if (mounted) {
          setState(() {
            _isPasswordSectionExpanded = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  InputDecoration _themedInputDecoration(String label, IconData iconData) {
    return InputDecoration(
      labelText: label,
      border: const UnderlineInputBorder(),
      prefixIcon: Icon(iconData, color: AppColors.secondaryIcon, size: 20),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2.0),
      ),
      labelStyle: TextStyle(color: AppColors.secondaryText),
      floatingLabelStyle: TextStyle(color: AppColors.primary),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String? value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryIcon, size: 22),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value ?? 'Not set',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userFromProvider = Provider.of<User?>(context);
    final User? user = FirebaseAuth.instance.currentUser ?? userFromProvider;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.appBarBackground,
          elevation: 1,
          iconTheme: IconThemeData(color: AppColors.primary),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('Loading user information...'),
            ],
          ),
        ),
      );
    }

    if (_displayedPhotoUrl == null ||
        (_displayedPhotoUrl != user.photoURL && _pickedImageFile == null)) {
      _displayedPhotoUrl = user.photoURL;
    }

    String initialLetter = "?";
    if (user.displayName?.isNotEmpty == true) {
      initialLetter = user.displayName![0];
    } else if (user.email?.isNotEmpty == true) {
      initialLetter = user.email![0];
    } else if (user.phoneNumber?.isNotEmpty == true) {
      initialLetter = user.phoneNumber![0];
    }

    final CardTheme cardTheme = CardTheme(
      elevation: 1.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
      ),
      color: Colors.white,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (mounted) {
              await user.reload();
              final refreshedUser = FirebaseAuth.instance.currentUser;
              setState(() {
                _displayedPhotoUrl = refreshedUser?.photoURL;
              });
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      key: ValueKey<String?>(
                        _pickedImageFile?.path ?? _displayedPhotoUrl,
                      ),
                      radius: 60,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      backgroundImage:
                          _pickedImageFile != null
                              ? FileImage(_pickedImageFile!)
                              : (_displayedPhotoUrl != null &&
                                          _displayedPhotoUrl!.isNotEmpty
                                      ? NetworkImage(_displayedPhotoUrl!)
                                      : null)
                                  as ImageProvider?,
                      child:
                          (_pickedImageFile == null &&
                                  (_displayedPhotoUrl == null ||
                                      _displayedPhotoUrl!.isEmpty))
                              ? Text(
                                initialLetter.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 40,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2.0,
                        child: InkWell(
                          onTap:
                              _isUploadingPhoto
                                  ? null
                                  : () => _showImageSourceActionSheet(context),
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child:
                                _isUploadingPhoto
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                      ),
                                    )
                                    : Icon(
                                      Icons.camera_alt,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle("Account"),
              Card(
                elevation: cardTheme.elevation,
                margin: cardTheme.margin,
                shape: cardTheme.shape,
                color: cardTheme.color,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.secondaryIcon,
                    size: 28,
                  ),
                  title: const Text(
                    'Personal Information',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Text(
                    user.displayName ??
                        user.email ??
                        user.phoneNumber ??
                        'Not set',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 28,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileDetailsScreen(),
                      ),
                    ).then((value) async {
                      if (value == true && mounted) {
                        await user.reload();
                        final refreshedUser = FirebaseAuth.instance.currentUser;
                        if (mounted) {
                          setState(() {
                            _displayedPhotoUrl = refreshedUser?.photoURL;
                          });
                        }
                      } else if (mounted) {
                        await user.reload();
                        final refreshedUser = FirebaseAuth.instance.currentUser;
                        if (mounted) {
                          setState(() {
                            _displayedPhotoUrl = refreshedUser?.photoURL;
                          });
                        }
                      }
                    });
                  },
                ),
              ),

              _buildSectionTitle("Contact Information"),
              Card(
                elevation: cardTheme.elevation,
                margin: cardTheme.margin,
                shape: cardTheme.shape,
                color: cardTheme.color,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        Icons.email_outlined,
                        "Email",
                        user.email,
                      ),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      _buildInfoRow(
                        context,
                        Icons.phone_outlined,
                        "Phone Number",
                        user.phoneNumber,
                      ),
                    ],
                  ),
                ),
              ),

              _buildSectionTitle("Login & Security"),
              Card(
                elevation: cardTheme.elevation,
                margin: cardTheme.margin,
                shape: cardTheme.shape,
                color: cardTheme.color,
                child: ExpansionTile(
                  key: GlobalKey(),
                  leading: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.secondaryIcon,
                  ),
                  title: const Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  iconColor: AppColors.primary,
                  collapsedIconColor: Colors.grey.shade500,
                  trailing: Icon(
                    _isPasswordSectionExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  onExpansionChanged: (bool expanded) {
                    if (mounted) {
                      setState(() {
                        _isPasswordSectionExpanded = expanded;
                      });
                    }
                  },
                  initiallyExpanded: _isPasswordSectionExpanded,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ).copyWith(bottom: 16.0),
                      child: Form(
                        key: _changePasswordFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _currentPasswordController,
                              decoration: _themedInputDecoration(
                                'Current Password',
                                Icons.lock_open_outlined,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureCurrentPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.secondaryIcon,
                                    size: 20,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscureCurrentPassword =
                                                !_obscureCurrentPassword,
                                      ),
                                ),
                              ),
                              obscureText: _obscureCurrentPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your current password.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: _themedInputDecoration(
                                'New Password',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.secondaryIcon,
                                    size: 20,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscureNewPassword =
                                                !_obscureNewPassword,
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
                              controller: _confirmNewPasswordController,
                              decoration: _themedInputDecoration(
                                'Confirm New Password',
                                Icons.lock_person_outlined,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.secondaryIcon,
                                    size: 20,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscureConfirmNewPassword =
                                                !_obscureConfirmNewPassword,
                                      ),
                                ),
                              ),
                              obscureText: _obscureConfirmNewPassword,
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
                            _isChangingPassword
                                ? Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                )
                                : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      44,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _changePassword,
                                  child: const Text('Save Changes'),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              ElevatedButton.icon(
                label: const Text('Logout'),
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
