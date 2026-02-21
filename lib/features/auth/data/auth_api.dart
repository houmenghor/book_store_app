import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'auth_models.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Endpoints.login,
      body: {
        'email': email,
        'password': password,
      },
    );

    final data = (response['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return AuthSession.fromJson(data);
  }

  Future<String> forgotPassword({required String email}) async {
    final response = await _client.post(
      Endpoints.forgotPassword,
      body: {'email': email},
    );
    return (response['message'] as String?) ?? 'If the email exists, an OTP has been sent.';
  }

  Future<void> sendOtp({
    required String email,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) async {
    await _client.post(
      Endpoints.otpSend,
      body: {
        'email': email,
        'purpose': purpose.value,
      },
    );
  }

  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String otp,
    OtpPurpose purpose = OtpPurpose.emailVerify,
  }) async {
    final response = await _client.post(
      Endpoints.otpVerify,
      body: {
        'email': email,
        'otp': otp,
        'purpose': purpose.value,
      },
    );

    final data = (response['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final user = data['user'];

    return OtpVerifyResult(
      message: (response['message'] as String?) ?? 'OTP verified.',
      user: user is Map<String, dynamic> ? UserModel.fromJson(user) : null,
    );
  }

  Future<String> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post(
      Endpoints.resetPassword,
      body: {
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return (response['message'] as String?) ?? 'Password reset successful.';
  }

  Future<UserModel> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? gender,
    String? dateOfBirth,
    String? profileImagePath,
  }) async {
    final files = <http.MultipartFile>[];
    final imagePath = (profileImagePath ?? '').trim();
    if (imagePath.isNotEmpty) {
      files.add(await http.MultipartFile.fromPath('profile_image', imagePath));
    }

    final response = await _client.multipartPost(
      Endpoints.updateProfile,
      authRequired: true,
      fields: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        if (gender != null && gender.trim().isNotEmpty) 'gender': gender,
        if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty)
          'date_of_birth': dateOfBirth,
      },
      files: files.isEmpty ? null : files,
    );

    final data = (response['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final userRaw = data['user'];
    final userMap = userRaw is Map<String, dynamic> ? userRaw : data;
    return UserModel.fromJson(userMap);
  }

  Future<void> logout() async {
    await _client.post(Endpoints.logout, authRequired: true);
  }
}
