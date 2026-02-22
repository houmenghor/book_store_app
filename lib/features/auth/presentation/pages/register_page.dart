import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/auth_api.dart';
import '../../data/auth_models.dart';
import '../../data/auth_repository.dart';
import '../../state/auth_provider.dart';
import '../widgets/auth_textfield.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;

  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _tokenStorage = TokenStorage();
    _apiClient = ApiClient(tokenStorage: _tokenStorage);
    _authProvider = AuthProvider(
      AuthRepository(
        api: AuthApi(_apiClient),
        tokenStorage: _tokenStorage,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _emailController.text.trim().contains('@') &&
        _phoneController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Email is required';
    }
    if (!text.contains('@') || !text.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Phone is required';
    }
    if (text.length < 8) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Password is required';
    }
    if (text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Confirm password is required';
    }
    if (text != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String _resolveError() {
    final details = _authProvider.errorDetails;
    if (details != null) {
      for (final entry in details.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          final msg = value.first.toString().trim();
          if (msg.isNotEmpty) {
            return msg;
          }
        }
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    final fallback = (_authProvider.error ?? '').trim();
    return fallback.isEmpty ? 'Register failed.' : fallback;
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final registered = await _authProvider.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone, // backend key: phone
      password: password,
      passwordConfirmation: confirmPassword,
    );

    if (!mounted) {
      return;
    }

    if (!registered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resolveError())),
      );
      return;
    }

    final otpSent = await _authProvider.sendOtp(
      email: email,
      purpose: OtpPurpose.emailVerify, // required purpose: email_verify
    );

    if (!mounted) {
      return;
    }

    if (!otpSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resolveError())),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Register successful. Verification OTP sent.')),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpPage(
          authProvider: _authProvider,
          initialEmail: email,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authProvider,
      builder: (_, __) {
        final loading = _authProvider.isLoading;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                autovalidateMode:
                    _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                child: Column(
                  children: [
                    const Text(
                      'Register',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    AuthTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hint: 'Enter your first name',
                      validator: (v) => _required(v, 'First name'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hint: 'Enter your last name',
                      validator: (v) => _required(v, 'Last name'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your phone number',
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      isObscure: true,
                      validator: _validatePassword,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Confirm Password',
                      isObscure: true,
                      validator: _validateConfirmPassword,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 30),
                    if (loading)
                      const CircularProgressIndicator()
                    else
                      AppButton(
                        text: 'Submit',
                        onPressed: _canSubmit ? _submit : null,
                      ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Have an account ?',
                        style: TextStyle(
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
