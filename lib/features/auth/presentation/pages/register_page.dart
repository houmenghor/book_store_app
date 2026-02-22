import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/auth_api.dart';
import '../../data/auth_models.dart';
import '../../data/auth_repository.dart';
import '../../state/auth_provider.dart';
import '../widgets/auth_textfield.dart';
import '../../../products/presentation/pages/product_list_page.dart';

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
    await _showRegisterOtpDialog(
      email: email,
      password: password,
    );
  }

  Future<void> _showRegisterOtpDialog({
    required String email,
    required String password,
  }) async {
    final controllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    final focusNodes = List<FocusNode>.generate(6, (_) => FocusNode());
    var isVerifying = false;
    var isResending = false;

    Future<void> handleVerify(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final code = controllers.map((c) => c.text.trim()).join();
      if (code.length != 6) {
        return;
      }

      var closedDialog = false;
      setDialogState(() => isVerifying = true);
      try {
        final verified = await _authProvider.verifyOtp(
          otp: code,
          purpose: OtpPurpose.emailVerify,
        );

        if (!verified) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_resolveError())),
          );
          return;
        }

        final loggedIn = await _authProvider.login(
          email: email,
          password: password,
        );

        if (!mounted) {
          return;
        }

        if (!loggedIn) {
          closedDialog = true;
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_resolveError())),
          );
          Navigator.pop(context);
          return;
        }

        closedDialog = true;
        Navigator.pop(dialogContext);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ProductListPage(),
          ),
          (route) => false,
        );
      } finally {
        if (mounted && !closedDialog) {
          setDialogState(() => isVerifying = false);
        }
      }
    }

    Future<void> handleResend(StateSetter setDialogState) async {
      setDialogState(() => isResending = true);
      try {
        final ok = await _authProvider.sendOtp(
          email: email,
          purpose: OtpPurpose.emailVerify,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'OTP resent to your email.' : _resolveError()),
          ),
        );
      } finally {
        if (mounted) {
          setDialogState(() => isResending = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final code = controllers.map((c) => c.text.trim()).join();
            final canVerify = code.length == 6 && !isVerifying;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        const Text(
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 6-digit code sent to\n$email',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(6, (index) {
                        return Container(
                          width: 32,
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            textInputAction:
                                index == 5 ? TextInputAction.done : TextInputAction.next,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                focusNodes[index - 1].requestFocus();
                              }
                              setDialogState(() {});
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: const Color(0xFFF7F8FC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE0E3EC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            canVerify ? () => handleVerify(setDialogState, dialogContext) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify Email'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive the code? ",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMain,
                          ),
                        ),
                        TextButton(
                          onPressed: isResending ? null : () => handleResend(setDialogState),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isResending ? 'Sending...' : 'Resend OTP',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in controllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
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
