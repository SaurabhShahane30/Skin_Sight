import 'package:acne_trial/splash_screen.dart';
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'intro1.dart';
import 'intro2.dart';
import 'intro3.dart';
import 'login_page.dart';

void main() {
  runApp(
      const MyApp(),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Skin Analysis Suite',
        debugShowCheckedModeBanner: false,
      theme: ThemeData(
      primarySwatch: Colors.teal,
      visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'RobotoSerif',
    ),
        home: const Intro1Screen() ,
    routes: {

    '/intro2': (_) => const Intro2Screen(),
    '/intro3': (_) => const Intro3Screen(),
    '/login': (_) => const LoginScreen(),
    '/home': (_) => HomeScreen(),

    },
    );
  }
}