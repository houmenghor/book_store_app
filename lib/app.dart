import 'package:flutter/material.dart';

import 'core/config/theme.dart';
import 'features/auth/presentation/pages/splash_page.dart';

class BookStoreApp extends StatelessWidget {
  const BookStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Store',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const SplashPage(),
    );
  }
}
