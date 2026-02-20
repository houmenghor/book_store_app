class UserModel {
  const UserModel({
    required this.id,
    required this.uuid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.profileImage,
    this.emailVerified = false,
  });

  final int id;
  final String uuid;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? profileImage;
  final bool emailVerified;

  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      profileImage: json['profile_image'] as String?,
      emailVerified: (json['email_verified'] as bool?) ?? false,
    );
  }
}

class AuthFlags {
  const AuthFlags({
    this.emailVerified = false,
    this.emailVerificationStatus,
    this.canShop = false,
  });

  final bool emailVerified;
  final String? emailVerificationStatus;
  final bool canShop;

  factory AuthFlags.fromJson(Map<String, dynamic> json) {
    return AuthFlags(
      emailVerified: (json['email_verified'] as bool?) ?? false,
      emailVerificationStatus: json['email_verification_status'] as String?,
      canShop: (json['can_shop'] as bool?) ?? false,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.flags,
  });

  final UserModel user;
  final String accessToken;
  final AuthFlags flags;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final flagsRaw = json['flags'];

    return AuthSession(
      user: UserModel.fromJson((json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      accessToken: (json['access_token'] as String?) ?? '',
      flags: AuthFlags.fromJson(
        (flagsRaw is Map<String, dynamic>) ? flagsRaw : <String, dynamic>{},
      ),
    );
  }
}

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.message,
    this.user,
  });

  final String message;
  final UserModel? user;
}

enum OtpPurpose {
  emailVerify('email_verify'),
  resetPassword('reset_password'),
  changeEmail('change_email');

  const OtpPurpose(this.value);

  final String value;
}
