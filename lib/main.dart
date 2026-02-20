import 'package:flutter/material.dart';
import 'core/config/theme.dart';
import 'features/auth/presentation/pages/splash_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Book Store',
      theme: appTheme, // Using the theme we defined
      home: const SplashPage(),
    );
  }
}