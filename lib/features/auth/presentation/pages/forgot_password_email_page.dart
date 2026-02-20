import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/widgets/app_button.dart';
import '../widgets/auth_textfield.dart';
import '../../data/auth_api.dart';
import 'forgot_password_otp_page.dart';

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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForgotPasswordOtpPage(email: email),
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

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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
