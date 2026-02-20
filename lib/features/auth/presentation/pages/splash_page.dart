import 'package:flutter/material.dart';
import 'dart:async';

import '../../../products/presentation/pages/product_list_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductListPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ensure you have added the image to pubspec.yaml
            Image.asset(
              'assets/images/logo.png', // Replace with your actual logo filename
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            // Optional: If the text is part of the image, remove this Text widget
            const Text(
              "BookStore",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100), // Orange/Red color from logo
              ),
            ),
             const Text(
              "APPLICATION",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1), // Blue color from logo
                letterSpacing: 2.0
              ),
            ),
          ],
        ),
      ),
    );
  }
}
