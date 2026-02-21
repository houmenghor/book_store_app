import 'package:flutter/material.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/storage/token_storage.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.isLoggedIn,
    required this.onLogout,
    required this.onLogin,
  });

  final String userName;
  final String userEmail;
  final String userPhone;
  final bool isLoggedIn;
  final Future<void> Function() onLogout;
  final Future<void> Function() onLogin;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isLoadingAction = false;
  late String _name;
  late String _email;
  late String _phone;

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _email = widget.userEmail;
    _phone = widget.userPhone;

    if (_email.trim().isEmpty || _phone.trim().isEmpty) {
      _reloadProfileFromStorage();
    }
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
        ),
      ),
    );

    if (updated == true) {
      await _reloadProfileFromStorage();
    }
  }

  Future<void> _reloadProfileFromStorage() async {
    final userName = await _tokenStorage.readUserName();
    final userEmail = await _tokenStorage.readUserEmail();
    final userPhone = await _tokenStorage.readUserPhone();

    if (!mounted) {
      return;
    }

    setState(() {
      _name = (userName ?? '').trim();
      _email = (userEmail ?? '').trim();
      _phone = (userPhone ?? '').trim();
    });
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
                    icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
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
                    _buildProfileCard(name, initials, email, phone),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Expanded(child: _StatsCard(count: '0', label: 'Orders')),
                        SizedBox(width: 10),
                        Expanded(child: _StatsCard(count: '0', label: 'Wishlist')),
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
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            onTap: _openEditProfile,
                          ),
                          const Divider(height: 1, color: Color(0xFFE8E9EF)),
                          _ProfileActionTile(
                            icon: Icons.favorite_border,
                            title: 'Wishlist',
                            onTap: () => _showComingSoon('Wishlist'),
                          ),
                          const Divider(height: 1, color: Color(0xFFE8E9EF)),
                          _ProfileActionTile(
                            icon: Icons.settings_outlined,
                            title: 'Account Settings',
                            onTap: () => _showComingSoon('Account Settings'),
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
                          widget.isLoggedIn ? Icons.logout : Icons.login,
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
              Container(
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
                    initials.isEmpty ? 'JD' : initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
              const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
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
              const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
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

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon.')),
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
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
