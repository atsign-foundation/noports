import 'package:flutter/material.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileListAddButton extends StatelessWidget {
  const ProfileListAddButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed: () {
          final uuid = Uuid.generate();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamed(Routes.profileForm, arguments: uuid);
          }
        },
        child: const Text("Add Profile"));
  }
}
