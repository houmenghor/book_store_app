import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.initialGender,
    required this.initialDateOfBirth,
  });

  final String initialName;
  final String initialPhone;
  final String initialGender;
  final String initialDateOfBirth;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  late final TokenStorage _tokenStorage = TokenStorage();
  late final AuthRepository _authRepository = AuthRepository(
    api: AuthApi(ApiClient(tokenStorage: _tokenStorage)),
    tokenStorage: _tokenStorage,
  );

  bool _isSaving = false;
  String? _selectedGender;
  String? _selectedImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  static const Map<String?, String> _genderOptions = <String?, String>{
    null: 'Prefer not to say',
    '1': 'Male',
    '2': 'Female',
  };

  @override
  void initState() {
    super.initState();

    final nameParts = widget.initialName.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _firstNameController.text = firstName;
    _lastNameController.text = lastName;
    _phoneController.text = widget.initialPhone.trim() == 'No phone'
        ? ''
        : widget.initialPhone.trim();
    _dateOfBirthController.text = widget.initialDateOfBirth.trim();

    final gender = widget.initialGender.trim().toLowerCase();
    if (gender == '1' || gender == 'male') {
      _selectedGender = '1';
    } else if (gender == '2' || gender == 'female') {
      _selectedGender = '2';
    } else {
      _selectedGender = null;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null || !mounted) {
      return;
    }

    _dateOfBirthController.text = _formatDate(picked);
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImagePath = picked.path;
      });
    } on PlatformException catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image picker is not ready. Please restart the app and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final dob = _dateOfBirthController.text.trim();

    setState(() => _isSaving = true);

    try {
      await _authRepository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        gender: _selectedGender,
        dateOfBirth: dob.isEmpty ? null : dob,
        profileImagePath: _selectedImagePath,
      );

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromNames(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.secondary, AppColors.primary],
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: _selectedImagePath == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                              ),
                            )
                          : Image.file(
                              File(_selectedImagePath!),
                              fit: BoxFit.cover,
                              width: 86,
                              height: 86,
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: InkWell(
                        onTap: _isSaving ? null : _pickProfileImage,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8E9EF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'First Name *',
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: _inputDecoration('John'),
                              validator: (value) => (value == null || value.trim().isEmpty)
                                  ? 'First name is required'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildField(
                            label: 'Last Name *',
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: _inputDecoration('Doe'),
                              validator: (value) => (value == null || value.trim().isEmpty)
                                  ? 'Last name is required'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      label: 'Phone Number *',
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration('+1234567890'),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Phone number is required'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      label: 'Gender',
                      child: DropdownButtonFormField<String?>(
                        value: _selectedGender,
                        decoration: _inputDecoration('Prefer not to say'),
                        items: _genderOptions.entries
                            .map(
                              (entry) => DropdownMenuItem<String?>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _selectedGender = value),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      label: 'Date of Birth',
                      child: TextFormField(
                        controller: _dateOfBirthController,
                        readOnly: true,
                        onTap: _pickDateOfBirth,
                        decoration: _inputDecoration('YYYY-MM-DD').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMain,
                    side: const BorderSide(color: Color(0xFFD8DCE7)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: const Color(0xFFF7F8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E3EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E3EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  String _initialsFromNames(String firstName, String lastName) {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final value = '$first$last';
    return value.isEmpty ? 'U' : value;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
