import 'package:acne_trial/signup.dart';
import 'package:acne_trial/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';
import 'intro1.dart';
import 'intro2.dart';
import 'intro3.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fbdbfpokalxnzlrhyqdx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZiZGJmcG9rYWx4bnpscmh5cWR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0ODUwMjMsImV4cCI6MjA2ODA2MTAyM30.vfWKOrsqGSCjrjq5JTq2YFFZiLbjSC_YQ4Rim8CN8S0',
  );


  runApp(MyApp());
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
      '/signup': (_) => const SignupPage(),
    '/home': (_) => HomeScreen(),

    },
    );
  }
}