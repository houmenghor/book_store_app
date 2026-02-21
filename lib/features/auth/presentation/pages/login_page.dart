import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../products/presentation/pages/product_list_page.dart';
import '../../data/auth_api.dart';
import '../../data/auth_models.dart';
import '../../data/auth_repository.dart';
import '../../state/auth_provider.dart';
import '../widgets/auth_textfield.dart';
import 'forgot_password_email_page.dart';
import 'otp_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;

  bool _showActivationAction = false;

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
    _emailController.dispose();
    _passwordController.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password.');
      return;
    }

    final ok = await _authProvider.login(email: email, password: password);
    if (!mounted) {
      return;
    }

    if (!ok) {
      final isInactive = _isInactiveAccountError(_authProvider.errorDetails);
      setState(() {
        _showActivationAction = isInactive;
      });

      if (isInactive) {
        _showMessage('Your account is not activated yet. Please activate via OTP.');
      } else {
        _showMessage(_authProvider.error ?? 'Login failed.');
      }
      return;
    }

    final session = _authProvider.session;
    if (session == null) {
      _showMessage('Login failed. Please try again.');
      return;
    }

    if (session.user.email.trim().isNotEmpty) {
      await _tokenStorage.saveUserEmail(session.user.email.trim());
    } else {
      await _tokenStorage.saveUserEmail(email);
    }
    final phone = (session.user.phone ?? '').trim();
    if (phone.isNotEmpty) {
      await _tokenStorage.saveUserPhone(phone);
    }

    final needsActivation = _isActivationPending(session);
    setState(() {
      _showActivationAction = needsActivation;
    });

    if (needsActivation) {
      _showMessage('Login success but account is not activated. Please verify your email OTP.');
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductListPage(),
      ),
      (route) => false,
    );
  }

  bool _isInactiveAccountError(Map<String, dynamic>? details) {
    if (details == null) {
      return false;
    }
    final emailErrors = details['email'];
    if (emailErrors is! List) {
      return false;
    }
    for (final item in emailErrors) {
      final text = item.toString().toLowerCase();
      if (text.contains('not activate yet') || text.contains('not activated yet')) {
        return true;
      }
    }
    return false;
  }

  bool _isActivationPending(AuthSession session) {
    if (!session.flags.emailVerified) {
      return true;
    }
    if (!session.flags.canShop) {
      return true;
    }
    return false;
  }

  Future<void> _goActivateAccount() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email first.');
      return;
    }

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

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authProvider,
      builder: (_, __) {
        final isLoading = _authProvider.isLoading;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    isObscure: true,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordEmailPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else
                    AppButton(
                      text: 'Submit',
                      onPressed: _submitLogin,
                    ),
                  if (_showActivationAction) ...[
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _goActivateAccount,
                      child: const Text('Activate account'),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterPage()),
                          );
                        },
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: Color(0xFF9C27B0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
