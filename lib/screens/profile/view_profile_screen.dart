import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final _displayNameController = TextEditingController();
  bool _isUpdatingProfile = false;

  final _changePasswordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmNewPassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile(String userId) async {
    if (_displayNameController.text.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isUpdatingProfile = true);
      try {
        final userAuth =
            Provider.of<AuthService>(context, listen: false).currentUser;
        if (userAuth != null &&
            userAuth.displayName != _displayNameController.text) {
          await userAuth.updateDisplayName(_displayNameController.text);
        }
        await Provider.of<FirestoreService>(
          context,
          listen: false,
        ).updateUserProfile(userId, displayName: _displayNameController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cập nhật hồ sơ thất bại: ${e.toString()}')),
          );
        }
        print("Error updating profile: $e");
      }
      if (mounted) {
        setState(() => _isUpdatingProfile = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên hiển thị')),
        );
      }
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(child: CircularProgressIndicator());
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
          SnackBar(content: Text('Lỗi đăng xuất: ${e.toString()}')),
        );
      }
      print('Lỗi đăng xuất: $e');
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
                'Mật khẩu mới không được trùng với mật khẩu hiện tại.',
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
              content: Text('Mật khẩu mới và xác nhận mật khẩu không khớp.'),
            ),
          );
        }
        return;
      }

      setState(() => _isChangingPassword = true);
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
            const SnackBar(content: Text('Đổi mật khẩu thành công!')),
          );
        }
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hồ sơ')),
            body: const Center(
              child: Text('Phiên đăng nhập đã kết thúc. Đang chuyển hướng...'),
            ),
          );
        }

        if (_displayNameController.text.isEmpty &&
            (user.displayName != null && user.displayName!.isNotEmpty)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _displayNameController.text.isEmpty) {
              _displayNameController.text = user.displayName!;
            }
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Hồ sơ')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blueGrey[100],
                      child: Text(
                        (user.displayName?.isNotEmpty == true
                                ? user.displayName![0]
                                : (user.email?[0] ?? '?'))
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 40,
                          color: Colors.blueGrey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'SĐT: ${user.email?.split('@')[0] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (user.email != null && user.email!.isNotEmpty)
                    Center(
                      child: Text(
                        'Email (Auth): ${user.email}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isUpdatingProfile
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Cập nhật thông tin'),
                        onPressed: () => _updateProfile(user.uid),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                  const SizedBox(height: 24),
                  const Divider(height: 32, thickness: 1),
                  Text(
                    'Đổi mật khẩu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _changePasswordFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _currentPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu hiện tại',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_open_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                              return 'Vui lòng nhập mật khẩu hiện tại';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu mới',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                              return 'Vui lòng nhập mật khẩu mới';
                            }
                            if (value.length < 6) {
                              return 'Mật khẩu phải có ít nhất 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmNewPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu mới',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_person_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                              return 'Vui lòng xác nhận mật khẩu mới';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Mật khẩu xác nhận không khớp';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _isChangingPassword
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                              icon: const Icon(Icons.key_outlined),
                              label: const Text('Đổi mật khẩu'),
                              onPressed: _changePassword,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
