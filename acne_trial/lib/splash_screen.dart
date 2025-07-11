import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'splash_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final splashProvider = Provider.of<SplashProvider>(context);

    if (splashProvider.isLoaded) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/intro1');
      });
    }


    return Scaffold(
      backgroundColor: const Color(0xFFFDF0D1),
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 250,
        ),
      ),
    );
  }
}
