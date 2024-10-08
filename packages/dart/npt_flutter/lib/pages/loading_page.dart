import 'package:flutter/material.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: NptAppBar(
        isNavigateBack: false,
        showSettings: false,
      ),
      body: Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}
