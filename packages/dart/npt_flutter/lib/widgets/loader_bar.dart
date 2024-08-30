import 'package:flutter/material.dart';

class LoaderBar extends StatelessWidget {
  const LoaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 400,
      child: LinearProgressIndicator(),
    );
  }
}
