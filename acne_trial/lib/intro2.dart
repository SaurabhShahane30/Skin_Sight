import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math';

class Intro2Screen extends StatelessWidget {
  const Intro2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0D1),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: pi / 2,
                child: Image.asset(
                  'assets/images/5.png',
                  width: 220,
                  height: 220,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Track acne, moisture, darkspots,\n and more – all in one scan',
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
                  Navigator.pushNamed(context, '/intro3');
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
