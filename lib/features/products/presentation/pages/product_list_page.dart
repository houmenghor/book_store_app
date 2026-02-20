import 'package:flutter/material.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../widgets/product_card.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isLoggedIn = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final token = await _tokenStorage.readToken();
    final userName = await _tokenStorage.readUserName();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = token != null && token.trim().isNotEmpty;
      _userName = (userName ?? '').trim();
    });
  }

  Future<void> _goToLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    if (!mounted) {
      return;
    }
    await _loadAuthState();
  }

  Future<void> _logout() async {
    await _tokenStorage.clearToken();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggedIn = false;
      _userName = '';
    });
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'profile':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile page is coming soon.')),
        );
        break;
      case 'my_books':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('My books page is coming soon.')),
        );
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/images/logo.png', width: 30),
                        const SizedBox(width: 8),
                      ],
                    ),
                    if (_isLoggedIn)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              _userName.isEmpty ? 'User' : _userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFE0E0E0),
                            child: Icon(Icons.person, color: Colors.black54, size: 18),
                          ),
                          PopupMenuButton<String>(
                            onSelected: _onMenuSelected,
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'name',
                                enabled: false,
                                child: Text(_userName.isEmpty ? 'User' : _userName),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 18),
                                    SizedBox(width: 8),
                                    Text('Profile'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'my_books',
                                child: Row(
                                  children: [
                                    Icon(Icons.menu_book_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('My books'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.power_settings_new, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Log out', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: _goToLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Sign', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', isSelected: true),
                    _buildFilterChip('Grammar'),
                    _buildFilterChip('Sevice'),
                    _buildFilterChip('Popular'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grid_view, size: 20, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search books you need ...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  suffixIcon: const Icon(Icons.search, color: Colors.black54),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Book Store', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    ProductCard(
                      title: 'Programming Books',
                      description: 'It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout',
                      imagePath: 'assets/images/book1.png',
                      rating: 4.5,
                      count: 120,
                      onViewMore: () {},
                    ),
                    ProductCard(
                      title: 'Grammar English Books',
                      description: 'It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout',
                      imagePath: 'assets/images/book2.png',
                      rating: 4.8,
                      count: 120,
                      onViewMore: () {},
                    ),
                    ProductCard(
                      title: 'History Books',
                      description: 'It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout',
                      imagePath: 'assets/images/book3.png',
                      rating: 4.2,
                      count: 120,
                      onViewMore: () {},
                    ),
                    ProductCard(
                      title: 'Grammar Books',
                      description: 'It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout',
                      imagePath: 'assets/images/book4.png',
                      rating: 4.2,
                      count: 120,
                      onViewMore: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined, color: Colors.black), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined, color: Colors.black), label: 'IG'),
          BottomNavigationBarItem(icon: Icon(Icons.send, color: Colors.black), label: 'Telegram'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline, color: Colors.black), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.share, color: Colors.black), label: 'Share'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}
