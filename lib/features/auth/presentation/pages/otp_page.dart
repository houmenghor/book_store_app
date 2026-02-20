import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../data/auth_models.dart';
import '../../state/auth_provider.dart';
import '../widgets/auth_textfield.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.authProvider,
    required this.initialEmail,
  });

  final AuthProvider authProvider;
  final String initialEmail;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final ok = await widget.authProvider.sendOtp(
      email: _emailController.text.trim(),
      purpose: OtpPurpose.emailVerify,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'OTP sent.' : (widget.authProvider.error ?? 'Failed to send OTP.')),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final ok = await widget.authProvider.verifyOtp(
      otp: _otpController.text.trim(),
      purpose: OtpPurpose.emailVerify,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'OTP verified.' : (widget.authProvider.error ?? 'OTP verification failed.')),
      ),
    );

    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authProvider,
      builder: (_, __) {
        final loading = widget.authProvider.isLoading;

        return Scaffold(
          appBar: AppBar(title: const Text('OTP Verification')),
          body: loading
              ? const LoadingView(label: 'Processing...')
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _otpController,
                        label: 'OTP (6 digits)',
                        hint: 'Enter OTP code',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Send OTP',
                        onPressed: _sendOtp,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _verifyOtp,
                          child: const Text('Verify OTP'),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
