class UserModel {
  const UserModel({
    required this.id,
    required this.uuid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.profileImage,
    this.emailVerified = false,
  });

  final int id;
  final String uuid;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? gender;
  final String? dateOfBirth;
  final String? profileImage;
  final bool emailVerified;

  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = _pickString(json, const ['first_name', 'firstName']);
    final lastName = _pickString(json, const ['last_name', 'lastName']);

    return UserModel(
      id: _asInt(json['id']),
      uuid: _asString(json['uuid']),
      firstName: firstName,
      lastName: lastName,
      email: _pickString(
        json,
        const ['email', 'user_email', 'gmail'],
      ),
      phone: _pickNullableString(
        json,
        const ['phone', 'phone_number', 'mobile', 'mobile_phone'],
      ),
      gender: _pickNullableString(json, const ['gender']),
      dateOfBirth: _pickNullableString(
        json,
        const ['date_of_birth', 'dob'],
      ),
      profileImage: _pickNullableString(
        json,
        const ['profile_image', 'avatar', 'image'],
      ),
      emailVerified: _asBool(json['email_verified']),
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
      emailVerified: _asBool(json['email_verified']),
      emailVerificationStatus: _asNullableString(json['email_verification_status']),
      canShop: _asBool(json['can_shop']),
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
      accessToken: _asString(json['access_token']),
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

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

String? _asNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = _asString(value).trim();
  return text.isEmpty ? null : text;
}

String _pickString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final text = _asString(json[key]).trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

String? _pickNullableString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    final text = key == 'gender' ? _normalizeGender(raw) : _asNullableString(raw);
    if (text != null) {
      return text;
    }
  }
  return null;
}

String? _normalizeGender(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    final code = value.toInt();
    if (code == 1 || code == 2) {
      return code.toString();
    }
    return null;
  }

  final text = _asString(value).trim().toLowerCase();
  if (text.isEmpty) {
    return null;
  }

  if (text == '1' || text == 'male') {
    return '1';
  }
  if (text == '2' || text == 'female') {
    return '2';
  }

  return null;
}
