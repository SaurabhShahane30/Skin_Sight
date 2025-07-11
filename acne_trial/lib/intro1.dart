import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class Intro1Screen extends StatelessWidget {
  const Intro1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0D1), // Cream background
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Shrinks to fit content
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/6.png',
                width: 220,
                height: 220,
              ),
              const SizedBox(height: 10),
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Welcome to SkinSight\nYour personal AI skincare expert.',
                    textAlign: TextAlign.center,
                    textStyle: TextStyle(
                      fontFamily: 'RobotoSerif',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF73397C),
                      shadows: [
                        Shadow(
                          offset: const Offset(2, 2),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.25),
                        ),
                      ],
                    ),
                    speed: const Duration(milliseconds: 60),
                  ),
                ],
                isRepeatingAnimation: false,
                totalRepeatCount: 1,
              ),
              const SizedBox(height: 80),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/intro2');
                },
                child: Image.asset(
                  'assets/images/arrow.png',
                  width: 60,
                  height: 60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
