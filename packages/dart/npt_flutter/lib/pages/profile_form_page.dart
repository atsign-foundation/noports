import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';

class ProfileFormPage extends StatelessWidget {
  const ProfileFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uuid = ModalRoute.of(context)!.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: ProfileFormView(uuid),
    );
  }
}
