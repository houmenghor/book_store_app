import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/widgets/app_button.dart';
import '../widgets/auth_textfield.dart';
import '../../data/auth_api.dart';
import '../../data/auth_models.dart';
import 'reset_password_page.dart';

class ForgotPasswordOtpPage extends StatefulWidget {
  const ForgotPasswordOtpPage({super.key, required this.email});

  final String email;

  @override
  State<ForgotPasswordOtpPage> createState() => _ForgotPasswordOtpPageState();
}

class _ForgotPasswordOtpPageState extends State<ForgotPasswordOtpPage> {
  final _otpController = TextEditingController();
  final _authApi = AuthApi(ApiClient(tokenStorage: TokenStorage()));
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showMessage('OTP must be 6 digits.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authApi.verifyOtp(
        email: widget.email,
        otp: otp,
        purpose: OtpPurpose.resetPassword,
      );
      if (!mounted) {
        return;
      }
      _showMessage(result.message);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: widget.email),
        ),
      );
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      final message = await _authApi.forgotPassword(email: widget.email);
      _showMessage(message);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'We sent OTP to ${widget.email}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              AuthTextField(
                controller: _otpController,
                label: 'OTP',
                hint: 'Enter 6-digit OTP',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    AppButton(
                      text: 'Confirm OTP',
                      onPressed: _verifyOtp,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _resendOtp,
                        child: const Text('Resend OTP'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
