import 'dart:ui';
import 'package:flutter/material.dart';

class ScanningOverlay extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback? onScanComplete;
  final int scanDurationSeconds;

  const ScanningOverlay({
    required this.width,
    required this.height,
    this.onScanComplete,
    this.scanDurationSeconds = 4,
    super.key,
  });

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: widget.scanDurationSeconds),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: -120,
      end: widget.height,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _startScan();
  }

  void _startScan() {
    _controller.repeat(reverse: false);
    Future.delayed(Duration(seconds: widget.scanDurationSeconds), () {
      if (!mounted) return;
      _controller.stop();
      setState(() {
        _isScanning = false;
      });
      widget.onScanComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            children: [
              // White corner brackets
              CustomPaint(
                size: Size(widget.width, widget.height),
                painter: CornerBracketsPainter(),
              ),

              // Scanning fading box
              if (_isScanning)
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Positioned(
                      top: _animation.value,
                      left: 0,
                      child: Container(
                        width: widget.width,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.green.withOpacity(0.4),
                              Colors.green.withOpacity(0.4),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.8, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    const radius = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(cornerLength, 0)
        ..lineTo(radius, 0)
        ..arcToPoint(Offset(0, radius), radius: Radius.circular(radius))
        ..lineTo(0, cornerLength),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius))
        ..lineTo(size.width, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLength)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(Offset(radius, size.height), radius: Radius.circular(radius))
        ..lineTo(cornerLength, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - cornerLength)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(Offset(size.width - radius, size.height),
            radius: Radius.circular(radius))
        ..lineTo(size.width - cornerLength, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
