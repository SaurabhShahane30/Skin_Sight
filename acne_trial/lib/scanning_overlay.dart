import 'package:flutter/material.dart';

class ScanningOverlay extends StatefulWidget {
  final double width;
  final double height;

  const ScanningOverlay({
    required this.width,
    required this.height,
    super.key,
  });

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: widget.height - 30, // Prevent it from going out of bounds
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Green scanning gradient animation
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              top: _animation.value,
              left: (MediaQuery.of(context).size.width - widget.width) / 2,
              child: Container(
                width: widget.width,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.greenAccent.withOpacity(0),
                      Colors.greenAccent.withOpacity(0.4),
                      Colors.greenAccent.withOpacity(0.7),
                      Colors.greenAccent.withOpacity(0.4),
                      Colors.greenAccent.withOpacity(0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            );
          },
        ),

        // White corner frame
        Center(
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
