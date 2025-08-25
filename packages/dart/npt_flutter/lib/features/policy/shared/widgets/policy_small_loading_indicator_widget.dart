import 'package:flutter/material.dart';

class PolicySmallLoadingIndicatorWidget extends StatelessWidget {
  const PolicySmallLoadingIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}