import 'package:flutter_test/flutter_test.dart';

import 'package:book_store/features/auth/data/auth_models.dart';
import 'package:book_store/features/auth/data/auth_repository.dart';
import 'package:book_store/features/auth/state/auth_provider.dart';

class _FakeAuthRepository implements IAuthRepository {
  @override
  Future<AuthSession> login({required String email, required String password}) async {
    return AuthSession(
      user: const UserModel(
        id: 1,
        uuid: 'user-uuid',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
      ),
      accessToken: 'token',
      flags: const AuthFlags(emailVerified: true, canShop: true),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendOtp({required String email, OtpPurpose purpose = OtpPurpose.emailVerify}) async {}

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String otp,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) async {
    return const OtpVerifyResult(message: 'ok');
  }
}

void main() {
  test('auth provider login success updates session', () async {
    final provider = AuthProvider(_FakeAuthRepository());

    final ok = await provider.login(email: 'test@example.com', password: 'Password123!');

    expect(ok, isTrue);
    expect(provider.isAuthenticated, isTrue);
    expect(provider.user?.email, 'test@example.com');
  });
}
