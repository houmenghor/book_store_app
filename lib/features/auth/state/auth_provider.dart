import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final IAuthRepository _repository;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _errorDetails;
  AuthSession? _session;
  String? _otpEmail;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get errorDetails => _errorDetails;
  AuthSession? get session => _session;
  UserModel? get user => _session?.user;
  bool get isAuthenticated => _session?.accessToken.isNotEmpty ?? false;
  String? get otpEmail => _otpEmail;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    _errorDetails = null;

    try {
      _session = await _repository.login(email: email, password: password);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? gender,
    String? dateOfBirth,
    String? profileImagePath,
  }) async {
    _setLoading(true);
    _error = null;
    _errorDetails = null;

    try {
      final user = await _repository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        profileImagePath: profileImagePath,
      );

      if (_session != null) {
        _session = AuthSession(
          user: user,
          accessToken: _session!.accessToken,
          flags: _session!.flags,
        );
      }
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendOtp({
    required String email,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) async {
    _setLoading(true);
    _error = null;
    _errorDetails = null;

    try {
      await _repository.sendOtp(email: email, purpose: purpose);
      _otpEmail = email;
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOtp({
    required String otp,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) async {
    if (_otpEmail == null || _otpEmail!.isEmpty) {
      _error = 'Please send OTP first.';
      _errorDetails = null;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;
    _errorDetails = null;

    try {
      await _repository.verifyOtp(email: _otpEmail!, otp: otp, purpose: purpose);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _error = null;
    _errorDetails = null;

    try {
      await _repository.logout();
      _session = null;
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  void _setError(Object e) {
    if (e is ApiException) {
      _error = e.message;
      _errorDetails = e.details;
      return;
    }
    _error = e.toString();
    _errorDetails = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
