import 'package:flutter/material.dart';

class SplashProvider with ChangeNotifier {
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  SplashProvider() {
    _initializeSplash();
  }

  Future<void> _initializeSplash() async {
    await Future.delayed(const Duration(seconds: 5));
    _isLoaded = true;
    notifyListeners();
  }
}
