import 'package:flutter/material.dart';

/// {@template enrollment_dialog}
/// A dialog widget that has some default styling.
///
/// The dialog includes padding, rounded corners, and a background color.
/// It also uses an [AnimatedSize] widget to animate size changes smoothly.
/// {@endtemplate}
class EnrollmentDialog extends StatelessWidget {
  /// {@macro enrollment_dialog}
  const EnrollmentDialog({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF3F3F3),
                ),
                padding: const EdgeInsets.all(32),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
