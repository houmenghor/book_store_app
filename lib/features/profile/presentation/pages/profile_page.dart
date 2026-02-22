import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/storage/wishlist_storage.dart';
import '../../../orders/data/order_api.dart';
import 'account_settings_page.dart';
import 'edit_profile_page.dart';
import 'wishlist_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userProfileImage,
    required this.isLoggedIn,
    required this.onLogout,
    required this.onLogin,
  });

  final String userName;
  final String userEmail;
  final String userPhone;
  final String userProfileImage;
  final bool isLoggedIn;
  final Future<void> Function() onLogout;
  final Future<void> Function() onLogin;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TokenStorage _tokenStorage = TokenStorage();
  late final WishlistStorage _wishlistStorage = WishlistStorage(
    tokenStorage: _tokenStorage,
  );
  late final OrderApi _orderApi = OrderApi(
    ApiClient(tokenStorage: _tokenStorage),
  );

  bool _isLoadingAction = false;
  late String _name;
  late String _email;
  late String _phone;
  late String _profileImageUrl;
  int _wishlistCount = 0;
  int _orderCount = 0;

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _email = widget.userEmail;
    _phone = widget.userPhone;
    _profileImageUrl = widget.userProfileImage;

    if (_email.trim().isEmpty || _phone.trim().isEmpty || _profileImageUrl.trim().isEmpty) {
      _reloadProfileFromStorage();
    }
    _reloadWishlistCount();
    _reloadOrderCount();
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoadingAction = true);
    await widget.onLogout();
    if (!mounted) {
      return;
    }
    setState(() => _isLoadingAction = false);
    Navigator.pop(context);
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoadingAction = true);
    await widget.onLogin();
    if (!mounted) {
      return;
    }
    await _reloadProfileFromStorage();
    await _reloadWishlistCount();
    await _reloadOrderCount();
    setState(() => _isLoadingAction = false);
  }

  Future<void> _openEditProfile() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      await _handleLogin();
      final refreshedToken = await _tokenStorage.readToken();
      if (!mounted || refreshedToken == null || refreshedToken.trim().isEmpty) {
        return;
      }
      await _reloadProfileFromStorage();
    }

    final gender = (await _tokenStorage.readUserGender())?.trim() ?? '';
    final dateOfBirth = (await _tokenStorage.readUserDateOfBirth())?.trim() ?? '';

    if (!mounted) {
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialName: _name,
          initialPhone: _phone,
          initialGender: gender,
          initialDateOfBirth: dateOfBirth,
          initialProfileImageUrl: _profileImageUrl,
        ),
      ),
    );

    if (updated == true) {
      await _reloadProfileFromStorage();
      await _reloadOrderCount();
    }
  }

  Future<void> _openWishlist() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WishlistPage(),
      ),
    );
    await _reloadWishlistCount();
  }

  Future<void> _openAccountSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSettingsPage(currentEmail: _email),
      ),
    );
  }

  Future<void> _reloadProfileFromStorage() async {
    final userName = await _tokenStorage.readUserName();
    final userEmail = await _tokenStorage.readUserEmail();
    final userPhone = await _tokenStorage.readUserPhone();
    final userProfileImage = await _tokenStorage.readUserProfileImage();

    if (!mounted) {
      return;
    }

    setState(() {
      _name = (userName ?? '').trim();
      _email = (userEmail ?? '').trim();
      _phone = (userPhone ?? '').trim();
      _profileImageUrl = (userProfileImage ?? '').trim();
    });
  }

  Future<void> _reloadWishlistCount() async {
    final items = await _wishlistStorage.readItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _wishlistCount = items.length;
    });
  }

  Future<void> _reloadOrderCount() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _orderCount = 0;
      });
      return;
    }

    try {
      final response = await _orderApi.getOrders(perPage: 1, page: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _orderCount = response.totalCount ?? response.orders.length;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _orderCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.trim().isEmpty ? 'John Doe' : _name.trim();
    final email = _email.trim().isEmpty ? 'No email' : _email.trim();
    final phone = _phone.trim().isEmpty ? 'No phone' : _phone.trim();
    final initials = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8E9EF)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
                  ),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileCard(name, initials, email, phone, _profileImageUrl),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatsCard(
                            count: _orderCount.toString(),
                            label: 'Orders',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatsCard(
                            count: _wishlistCount.toString(),
                            label: 'Wishlist',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E9EF)),
                      ),
                      child: Column(
                        children: [
                          _ProfileActionTile(
                            icon: LucideIcons.user,
                            title: 'Edit Profile',
                            onTap: _openEditProfile,
                          ),
                          const Divider(height: 1, color: Color(0xFFE8E9EF)),
                          _ProfileActionTile(
                            icon: LucideIcons.heart,
                            title: 'Wishlist',
                            onTap: _openWishlist,
                          ),
                          const Divider(height: 1, color: Color(0xFFE8E9EF)),
                          _ProfileActionTile(
                            icon: LucideIcons.settings,
                            title: 'Account Settings',
                            onTap: _openAccountSettings,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingAction
                            ? null
                            : (widget.isLoggedIn ? _handleLogout : _handleLogin),
                        icon: Icon(
                          widget.isLoggedIn ? LucideIcons.logOut : LucideIcons.logIn,
                          size: 18,
                        ),
                        label: Text(widget.isLoggedIn ? 'Logout' : 'Login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMain,
                          side: const BorderSide(color: Color(0xFFD8DCE7)),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    String name,
    String initials,
    String email,
    String phone,
    String profileImageUrl,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatar(
                initials: initials.isEmpty ? 'JD' : initials,
                imageUrl: profileImageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Book Lover',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(LucideIcons.mail, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.phone, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phone,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.imageUrl,
  });

  final String initials;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isNotEmpty) {
      return ClipOval(
        child: Container(
          width: 56,
          height: 56,
          color: const Color(0xFFF0F1F6),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.primary],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.count,
    required this.label,
  });

  final String count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E9EF)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMain),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
