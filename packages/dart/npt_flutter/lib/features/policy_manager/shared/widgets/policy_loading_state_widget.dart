import 'package:flutter/material.dart';

class PolicyLoadingStateWidget extends StatelessWidget {
  final String message;
  final double? indicatorSize;

  const PolicyLoadingStateWidget({
    super.key,
    this.message = 'Loading...',
    this.indicatorSize,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: indicatorSize ?? 32,
            height: indicatorSize ?? 32,
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}