import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

abstract class IAuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<void> sendOtp({required String email, OtpPurpose purpose});
  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String otp,
    OtpPurpose purpose,
  });
  Future<void> logout();
}

class AuthRepository implements IAuthRepository {
  const AuthRepository({
    required AuthApi api,
    required TokenStorage tokenStorage,
  })  : _api = api,
        _tokenStorage = tokenStorage;

  final AuthApi _api;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _api.login(email: email, password: password);
    if (session.accessToken.isNotEmpty) {
      await _tokenStorage.saveToken(session.accessToken);
      await _tokenStorage.saveUserName(session.user.fullName);
    }
    return session;
  }

  @override
  Future<void> sendOtp({
    required String email,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) {
    return _api.sendOtp(email: email, purpose: purpose);
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String otp,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) {
    return _api.verifyOtp(email: email, otp: otp, purpose: purpose);
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      await _tokenStorage.clearToken();
    }
  }
}
