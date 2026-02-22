import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/widgets/app_button.dart';
import '../widgets/auth_textfield.dart';
import '../../data/auth_api.dart';
import '../../data/auth_models.dart';
import 'reset_password_page.dart';

class ForgotPasswordEmailPage extends StatefulWidget {
  const ForgotPasswordEmailPage({super.key});

  @override
  State<ForgotPasswordEmailPage> createState() => _ForgotPasswordEmailPageState();
}

class _ForgotPasswordEmailPageState extends State<ForgotPasswordEmailPage> {
  final _emailController = TextEditingController();
  final _authApi = AuthApi(ApiClient(tokenStorage: TokenStorage()));
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final message = await _authApi.forgotPassword(email: email);
      if (!mounted) {
        return;
      }
      _showMessage(message);
      await _showForgotPasswordOtpDialog(email);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _showForgotPasswordOtpDialog(String email) async {
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
        final result = await _authApi.verifyOtp(
          email: email,
          otp: code,
          purpose: OtpPurpose.resetPassword,
        );

        if (!mounted) {
          return;
        }

        closedDialog = true;
        Navigator.pop(dialogContext);
        _showMessage(result.message);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(email: email),
          ),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }
        _showMessage(e.toString());
      } finally {
        if (mounted && !closedDialog) {
          setDialogState(() => isVerifying = false);
        }
      }
    }

    Future<void> handleResend(StateSetter setDialogState) async {
      setDialogState(() => isResending = true);
      try {
        final message = await _authApi.forgotPassword(email: email);
        if (!mounted) {
          return;
        }
        _showMessage(message);
      } catch (e) {
        if (!mounted) {
          return;
        }
        _showMessage(e.toString());
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
                          'Verify OTP',
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
                            : const Text('Verify OTP'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Enter your email to receive OTP.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              AuthTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                AppButton(
                  text: 'Send OTP',
                  onPressed: _sendOtp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
