import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

abstract class IAuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<String> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  });
  Future<UserModel> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? gender,
    String? dateOfBirth,
    String? profileImagePath,
  });
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
      final resolvedEmail = session.user.email.trim().isNotEmpty
          ? session.user.email.trim()
          : email.trim();
      final resolvedPhone = (session.user.phone ?? '').trim();

      await _tokenStorage.saveToken(session.accessToken);
      await _tokenStorage.saveUserName(session.user.fullName);
      await _tokenStorage.saveUserEmail(resolvedEmail);
      if (resolvedPhone.isNotEmpty) {
        await _tokenStorage.saveUserPhone(resolvedPhone);
      }
      final profileImage = (session.user.profileImage ?? '').trim();
      if (profileImage.isNotEmpty) {
        await _tokenStorage.saveUserProfileImage(profileImage);
      }
      await _tokenStorage.saveUserGender((session.user.gender ?? '').trim());
      if ((session.user.dateOfBirth ?? '').trim().isNotEmpty) {
        await _tokenStorage.saveUserDateOfBirth(session.user.dateOfBirth!.trim());
      }
    }
    return session;
  }

  @override
  Future<String> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) {
    return _api.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  @override
  Future<UserModel> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? gender,
    String? dateOfBirth,
    String? profileImagePath,
  }) async {
    final user = await _api.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      gender: gender,
      dateOfBirth: dateOfBirth,
      profileImagePath: profileImagePath,
    );

    await _tokenStorage.saveUserName(user.fullName);
    if (user.email.trim().isNotEmpty) {
      await _tokenStorage.saveUserEmail(user.email.trim());
    }
    if ((user.phone ?? '').trim().isNotEmpty) {
      await _tokenStorage.saveUserPhone(user.phone!.trim());
    }
    if ((user.profileImage ?? '').trim().isNotEmpty) {
      await _tokenStorage.saveUserProfileImage(user.profileImage!.trim());
    }
    await _tokenStorage.saveUserGender((user.gender ?? '').trim());
    if ((user.dateOfBirth ?? '').trim().isNotEmpty) {
      await _tokenStorage.saveUserDateOfBirth(user.dateOfBirth!.trim());
    }

    return user;
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) {
    return _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );
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
