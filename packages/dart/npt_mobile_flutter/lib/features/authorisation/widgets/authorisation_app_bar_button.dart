import 'package:flutter/material.dart';

/// Authorisation feature is not available on mobile
/// This widget is kept for compatibility but returns an empty widget
class AuthorisationAppBarButton extends StatelessWidget {
  const AuthorisationAppBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Authorisation is a desktop-only feature
    return const SizedBox.shrink();
  }
}
