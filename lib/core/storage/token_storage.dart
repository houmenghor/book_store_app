import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_access_token';
  static const String _userNameKey = 'auth_user_name';
  static const String _userEmailKey = 'auth_user_email';
  static const String _userPhoneKey = 'auth_user_phone';
  static const String _userProfileImageKey = 'auth_user_profile_image';
  static const String _userGenderKey = 'auth_user_gender';
  static const String _userDobKey = 'auth_user_dob';
  static const String _pendingChangeEmailKey = 'auth_pending_change_email';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUserName(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, userName);
  }

  Future<String?> readUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> readUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  Future<void> saveUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPhoneKey, phone);
  }

  Future<String?> readUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  Future<void> saveUserProfileImage(String imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileImageKey, imageUrl);
  }

  Future<String?> readUserProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userProfileImageKey);
  }

  Future<void> saveUserGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userGenderKey, gender);
  }

  Future<String?> readUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userGenderKey);
  }

  Future<void> saveUserDateOfBirth(String dateOfBirth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDobKey, dateOfBirth);
  }

  Future<String?> readUserDateOfBirth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userDobKey);
  }

  Future<void> savePendingChangeEmail(
    String email, {
    String? accountKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingEmailStorageKey(accountKey), email);
  }

  Future<String?> readPendingChangeEmail({String? accountKey}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingEmailStorageKey(accountKey));
  }

  Future<void> clearPendingChangeEmail({String? accountKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingEmailStorageKey(accountKey));
  }

  String _pendingEmailStorageKey(String? accountKey) {
    final normalized = (accountKey ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return _pendingChangeEmailKey;
    }

    final safe = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '${_pendingChangeEmailKey}_$safe';
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userProfileImageKey);
    await prefs.remove(_userGenderKey);
    await prefs.remove(_userDobKey);
    await prefs.remove(_pendingChangeEmailKey);
  }
}
