import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:email_application/services/firestore_service.dart';

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

  @override
  void dispose() {
    _displayNameController.dispose();
    _dobController.dispose();
    super.dispose();
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
          SnackBar(
            content: Text('Error loading profile information: ${e.toString()}'),
          ),
        );
      }
    }
  }

  InputDecoration _themedInputDecoration(
    String label,
    IconData iconData,
    ThemeData theme,
  ) {
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
          const SnackBar(content: Text('Information updated successfully!')),
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
          SnackBar(content: Text('Update error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDisplayItem(
    IconData icon,
    String label,
    String? value,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: theme.textTheme.bodyMedium?.color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: theme.textTheme.bodyLarge),
          const Spacer(),
          Expanded(
            child: Text(
              value ?? 'Not updated yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal information'),
        elevation: 1,
        actions: [
          if (!_isEditing && !_isLoading)
            TextButton(
              onPressed: () {
                if (mounted) setState(() => _isEditing = true);
              },
              child: const Text('Edit', style: TextStyle(fontSize: 16)),
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
                'Cancel',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
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
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
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
                                    color: theme.primaryColor,
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
                            'Display name',
                            Icons.person_rounded,
                            theme,
                          ),
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'Please enter name.'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobController,
                          decoration: _themedInputDecoration(
                            'Date of birth',
                            Icons.calendar_today_rounded,
                            theme,
                          ).copyWith(hintText: 'Tap to select date'),
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
                                return child!;
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
                                      ? 'Please select date of birth.'
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
                            'Gender',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Male'),
                                value: 'Male',
                                groupValue: _selectedGender,
                                onChanged:
                                    (value) =>
                                        setState(() => _selectedGender = value),
                                activeColor: theme.primaryColor,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Female'),
                                value: 'Female',
                                groupValue: _selectedGender,
                                onChanged:
                                    (value) =>
                                        setState(() => _selectedGender = value),
                                activeColor: theme.primaryColor,
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
                              'Please select gender.',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 32,
                            ),
                          ),
                          child:
                              _isLoading
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: theme.colorScheme.onPrimary,
                                      strokeWidth: 3,
                                    ),
                                  )
                                  : const Text('Save'),
                        ),
                      ] else ...[
                        _buildDisplayItem(
                          Icons.person_outline_rounded,
                          "Name",
                          _displayNameController.text.isNotEmpty
                              ? _displayNameController.text
                              : 'Not updated yet',
                          theme,
                        ),
                        const Divider(),
                        _buildDisplayItem(
                          Icons.cake_outlined,
                          "Date of birth",
                          _selectedDateOfBirth != null
                              ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(_selectedDateOfBirth!)
                              : 'Not updated yet',
                          theme,
                        ),
                        const Divider(),
                        _buildDisplayItem(
                          Icons.wc_outlined,
                          "Gender",
                          _selectedGender ?? 'Not updated yet',
                          theme,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
