import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/config/app_colors.dart';

class EditProfileDetailsScreen extends StatefulWidget {
  const EditProfileDetailsScreen({super.key});

  @override
  State<EditProfileDetailsScreen> createState() =>
      _EditProfileDetailsScreenState();
}

class _EditProfileDetailsScreenState extends State<EditProfileDetailsScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayNameController;
  late TextEditingController _dobController;
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;

  User? _currentUser;
  Map<String, dynamic>? _userProfileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _dobController = TextEditingController();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    try {
      _userProfileData = await firestoreService.getUserProfile(
        _currentUser!.uid,
      );

      if (mounted) {
        setState(() {
          _displayNameController.text =
              _userProfileData?['displayName'] ??
              _currentUser?.displayName ??
              '';
          _selectedGender = _userProfileData?['gender'];

          Timestamp? dobTimestamp =
              _userProfileData?['dateOfBirth'] as Timestamp?;
          if (dobTimestamp != null) {
            _selectedDateOfBirth = dobTimestamp.toDate();
            _dobController.text = DateFormat(
              'dd/MM/yyyy',
            ).format(_selectedDateOfBirth!);
          } else {
            _dobController.text = '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user profile in EditScreen: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thông tin hồ sơ: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  InputDecoration _themedInputDecoration(
    String label,
    IconData iconData,
    bool isFocused,
  ) {
    final Color iconColor =
        isFocused ? AppColors.primary : AppColors.secondaryIcon;
    final Color labelColor =
        isFocused ? AppColors.primary : AppColors.secondaryText;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: labelColor),
      prefixIcon: Icon(iconData, color: iconColor),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) return;

    if (mounted) setState(() => _isLoading = true);

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final String newDisplayName = _displayNameController.text.trim();

    try {
      if (newDisplayName != _currentUser!.displayName) {
        await _currentUser!.updateDisplayName(newDisplayName);
        await _currentUser!.reload();
      }

      await firestoreService.createUserProfile(
        user: _currentUser!,
        phoneNumber:
            _currentUser!.phoneNumber ?? _userProfileData?['phoneNumber'] ?? '',
        customEmail:
            _currentUser!.email ?? _userProfileData?['customEmail'] ?? '',
        displayName: newDisplayName,
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth,
        isProfileFullyCompleted: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thông tin thành công!')),
        );
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        _loadUserProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDisplayItem(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryIcon, size: 24),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value ?? 'Chưa cập nhật',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thông tin cá nhân',
          style: TextStyle(
            color: AppColors.appBarForeground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appBarBackground,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.primary),
        actions: [
          if (!_isEditing && !_isLoading)
            TextButton(
              onPressed: () {
                if (mounted) setState(() => _isEditing = true);
              },
              child: Text(
                'Chỉnh sửa',
                style: TextStyle(color: AppColors.primary, fontSize: 16),
              ),
            ),
          if (_isEditing && !_isLoading)
            TextButton(
              onPressed: () {
                if (mounted) {
                  setState(() => _isEditing = false);
                  _loadUserProfile();
                }
              },
              child: Text(
                'Hủy',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode:
                      _isEditing
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage:
                            _currentUser?.photoURL != null &&
                                    _currentUser!.photoURL!.isNotEmpty
                                ? NetworkImage(_currentUser!.photoURL!)
                                : null,
                        child:
                            (_currentUser?.photoURL == null ||
                                    _currentUser!.photoURL!.isEmpty)
                                ? Text(
                                  (_currentUser?.displayName?.isNotEmpty == true
                                          ? _currentUser!.displayName![0]
                                          : (_currentUser?.email?.isNotEmpty ==
                                                  true
                                              ? _currentUser!.email![0]
                                              : '?'))
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 40,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                : null,
                      ),
                      const SizedBox(height: 24),
                      if (_isEditing) ...[
                        TextFormField(
                          controller: _displayNameController,
                          decoration: _themedInputDecoration(
                            'Tên hiển thị',
                            Icons.person_rounded,
                            true,
                          ),
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'Vui lòng nhập tên.'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobController,
                          decoration: _themedInputDecoration(
                            'Ngày sinh',
                            Icons.calendar_today_rounded,
                            true,
                          ).copyWith(hintText: 'Chạm để chọn ngày'),
                          readOnly: true,
                          onTap: () async {
                            FocusScope.of(context).requestFocus(FocusNode());
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedDateOfBirth ??
                                  DateTime.now().subtract(
                                    const Duration(days: 365 * 18),
                                  ),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now().subtract(
                                const Duration(days: 365 * 5),
                              ),
                              locale: const Locale('vi', 'VN'),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: AppColors.primary,
                                      onPrimary: AppColors.onPrimary,
                                    ),
                                    dialogBackgroundColor: Colors.white,
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedDate != null &&
                                pickedDate != _selectedDateOfBirth) {
                              if (mounted) {
                                setState(() {
                                  _selectedDateOfBirth = pickedDate;
                                  _dobController.text = DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(pickedDate);
                                });
                              }
                            }
                          },
                          validator:
                              (value) =>
                                  _selectedDateOfBirth == null
                                      ? 'Vui lòng chọn ngày sinh.'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12.0,
                            right: 12.0,
                            top: 8.0,
                            bottom: 0,
                          ),
                          child: Text(
                            'Giới tính',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Nam'),
                                value: 'Nam',
                                groupValue: _selectedGender,
                                onChanged:
                                    (value) =>
                                        setState(() => _selectedGender = value),
                                activeColor: AppColors.primary,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Nữ'),
                                value: 'Nữ',
                                groupValue: _selectedGender,
                                onChanged:
                                    (value) =>
                                        setState(() => _selectedGender = value),
                                activeColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedGender == null &&
                            _formKey.currentState?.validate() == false &&
                            _isEditing)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 0),
                            child: Text(
                              'Vui lòng chọn giới tính.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 32,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                  : const Text('Lưu'),
                        ),
                      ] else ...[
                        _buildDisplayItem(
                          Icons.person_outline_rounded,
                          "Tên",
                          _displayNameController.text.isNotEmpty
                              ? _displayNameController.text
                              : 'Chưa cập nhật',
                        ),
                        const Divider(),
                        _buildDisplayItem(
                          Icons.cake_outlined,
                          "Ngày sinh",
                          _selectedDateOfBirth != null
                              ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(_selectedDateOfBirth!)
                              : 'Chưa cập nhật',
                        ),
                        const Divider(),
                        _buildDisplayItem(
                          Icons.wc_outlined,
                          "Giới tính",
                          _selectedGender ?? 'Chưa cập nhật',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
