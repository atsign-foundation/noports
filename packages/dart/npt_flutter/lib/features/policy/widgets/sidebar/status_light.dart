import 'package:flutter/material.dart';

class StatusLight extends StatelessWidget {
  const StatusLight({
    super.key,
    required this.color,
    this.size = 14,
    this.animationDuration = const Duration(milliseconds: 200),
    this.glowOpacity = 0.45,
  });

  final Color color;
  final double size;
  final Duration animationDuration;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(glowOpacity),
            blurRadius: size * 0.45 + 0.5,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}
