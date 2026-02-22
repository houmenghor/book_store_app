import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_models.dart';
import '../../../auth/data/auth_repository.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.currentEmail,
  });

  final String currentEmail;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _changeEmailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TokenStorage _tokenStorage = TokenStorage();
  late final AuthRepository _authRepository = AuthRepository(
    api: AuthApi(ApiClient(tokenStorage: _tokenStorage)),
    tokenStorage: _tokenStorage,
  );

  late final TextEditingController _currentEmailController;
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSendingCode = false;
  bool _isUpdatingPassword = false;
  bool _emailFormSubmitted = false;
  bool _passwordFormSubmitted = false;
  String? _pendingEmail;

  String get _pendingEmailAccountKey {
    final currentEmail = _currentEmailController.text.trim();
    if (currentEmail.isNotEmpty && currentEmail != 'No email') {
      return currentEmail;
    }
    return widget.currentEmail.trim();
  }

  @override
  void initState() {
    super.initState();
    final currentEmail = widget.currentEmail.trim();
    _currentEmailController = TextEditingController(
      text: currentEmail.isEmpty || currentEmail == 'No email'
          ? ''
          : currentEmail,
    );
    _loadPendingEmailFromStorage();
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isEmailFormValidForSubmit {
    final currentEmail = _currentEmailController.text.trim();
    final newEmail = _newEmailController.text.trim();
    if (newEmail.isEmpty) {
      return false;
    }
    if (!newEmail.contains('@') || !newEmail.contains('.')) {
      return false;
    }
    if (currentEmail.isNotEmpty && newEmail == currentEmail) {
      return false;
    }
    return true;
  }

  Future<void> _loadPendingEmailFromStorage() async {
    final storedPendingEmail = (await _tokenStorage.readPendingChangeEmail(
      accountKey: _pendingEmailAccountKey,
    ))
            ?.trim() ??
        '';
    final currentEmail = _currentEmailController.text.trim();

    if (!mounted) {
      return;
    }

    if (storedPendingEmail.isEmpty) {
      return;
    }

    if (currentEmail.isNotEmpty && storedPendingEmail == currentEmail) {
      await _tokenStorage.clearPendingChangeEmail(
        accountKey: _pendingEmailAccountKey,
      );
      return;
    }

    setState(() {
      _pendingEmail = storedPendingEmail;
      if (_newEmailController.text.trim().isEmpty) {
        _newEmailController.text = storedPendingEmail;
      }
    });
  }

  bool get _isPasswordFormValidForSubmit {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (currentPassword.isEmpty) {
      return false;
    }
    if (newPassword.length < 8) {
      return false;
    }
    if (confirmPassword.isEmpty) {
      return false;
    }
    if (newPassword != confirmPassword) {
      return false;
    }
    return true;
  }

  Future<void> _submitChangeEmail() async {
    setState(() => _emailFormSubmitted = true);
    if (!_changeEmailFormKey.currentState!.validate()) {
      return;
    }

    final newEmail = _newEmailController.text.trim();

    setState(() => _isSendingCode = true);
    try {
      final message = await _authRepository.changeEmail(
        newEmail: newEmail,
      );
      await _tokenStorage.savePendingChangeEmail(
        newEmail,
        accountKey: _pendingEmailAccountKey,
      );

      setState(() {
        _pendingEmail = newEmail;
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _showVerifyEmailDialog(newEmail);
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
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _openVerifyPendingEmail() async {
    final pendingEmail = _pendingEmail?.trim();
    if (pendingEmail == null || pendingEmail.isEmpty) {
      return;
    }
    await _showVerifyEmailDialog(pendingEmail);
  }

  Future<void> _cancelPendingEmail() async {
    await _tokenStorage.clearPendingChangeEmail(
      accountKey: _pendingEmailAccountKey,
    );
    setState(() {
      _pendingEmail = null;
    });
  }

  Future<void> _showVerifyEmailDialog(String email) async {
    final controllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    final focusNodes = List<FocusNode>.generate(6, (_) => FocusNode());
    bool isVerifying = false;
    bool isResending = false;

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
        final result = await _authRepository.verifyOtp(
          email: email,
          otp: code,
          purpose: OtpPurpose.changeEmail,
        );
        final updatedEmail = (result.user?.email ?? email).trim().isNotEmpty
            ? (result.user?.email ?? email).trim()
            : email;

        final pendingAccountKey = _pendingEmailAccountKey;
        await _tokenStorage.saveUserEmail(updatedEmail);
        await _tokenStorage.clearPendingChangeEmail(accountKey: pendingAccountKey);
        _currentEmailController.text = updatedEmail;
        _newEmailController.clear();

        if (!mounted) {
          return;
        }
        setState(() {
          _pendingEmail = null;
        });

        closedDialog = true;
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.trim().isEmpty
                  ? 'New email verified successfully.'
                  : result.message,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }
        final message = e is ApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
        await _authRepository.resendOtp(
          email: email,
          purpose: OtpPurpose.changeEmail,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent to your new email.')),
        );
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
                          icon: const Icon(LucideIcons.x, size: 18),
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
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                        onPressed: canVerify
                            ? () => handleVerify(setDialogState, dialogContext)
                            : null,
                        style: _filledButtonStyle(isEnabled: canVerify),
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

  Future<void> _submitChangePassword() async {
    setState(() => _passwordFormSubmitted = true);
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() => _isUpdatingPassword = true);
    try {
      final message = await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: confirmPassword,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
        setState(() => _isUpdatingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8E9EF)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
                  ),
                  const Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSectionCard(
                      icon: LucideIcons.mail,
                      title: 'Change Email',
                      child: Form(
                        key: _changeEmailFormKey,
                        autovalidateMode: _emailFormSubmitted
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          children: [
                            _buildFieldLabel('Current Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _currentEmailController,
                              readOnly: true,
                              decoration: _inputDecoration('Current email').copyWith(
                                filled: true,
                                fillColor: const Color(0xFFF2F3F8),
                              ),
                            ),
                            if ((_pendingEmail ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildPendingEmailCard(_pendingEmail!.trim()),
                            ],
                            const SizedBox(height: 12),
                            _buildFieldLabel('New Email Address'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _newEmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration('newemail@example.com'),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'New email is required';
                                }
                                if (!text.contains('@') || !text.contains('.')) {
                                  return 'Enter a valid email';
                                }
                                if (text == _currentEmailController.text.trim()) {
                                  return 'New email must be different';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isSendingCode || !_isEmailFormValidForSubmit)
                                    ? null
                                    : _submitChangeEmail,
                                style: _filledButtonStyle(
                                  isEnabled: !_isSendingCode && _isEmailFormValidForSubmit,
                                ),
                                child: _isSendingCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Send Verification Code'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      icon: LucideIcons.lock,
                      title: 'Update Password',
                      child: Form(
                        key: _passwordFormKey,
                        autovalidateMode: _passwordFormSubmitted
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          children: [
                            _buildFieldLabel('Current Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: _inputDecoration('********'),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Current password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('New Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: _inputDecoration('********'),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'New password is required';
                                }
                                if (text.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Password must be at least 8 characters',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Confirm New Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: _inputDecoration('********'),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'Confirm password is required';
                                }
                                if (text != _newPasswordController.text.trim()) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isUpdatingPassword || !_isPasswordFormValidForSubmit)
                                    ? null
                                    : _submitChangePassword,
                                style: _filledButtonStyle(
                                  isEnabled: !_isUpdatingPassword && _isPasswordFormValidForSubmit,
                                ),
                                child: _isUpdatingPassword
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Update Password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMain),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMain,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPendingEmailCard(String pendingEmail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E3EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.info,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Email\nVerification',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pendingEmail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _openVerifyPendingEmail,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMain,
                  backgroundColor: const Color(0xFFF1F2F7),
                  minimumSize: const Size(56, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Verify'),
              ),
              TextButton(
                onPressed: _cancelPendingEmail,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMain),
                ),
              ),
            ],
          ),
        ],
      ),
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

  ButtonStyle _filledButtonStyle({required bool isEnabled}) {
    final backgroundColor = isEnabled
        ? AppColors.primary
        : AppColors.primary.withOpacity(0.45);
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      disabledBackgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(double.infinity, 42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
