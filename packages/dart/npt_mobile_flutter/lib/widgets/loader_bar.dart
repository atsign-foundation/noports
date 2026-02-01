import 'package:flutter/material.dart';

class LoaderBar extends StatelessWidget {
  const LoaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth < 700 ? screenWidth * 0.8 : 400.0;
    return SizedBox(width: width, child: const LinearProgressIndicator());
  }
}
