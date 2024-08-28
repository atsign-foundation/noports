import 'package:flutter/material.dart';
import 'package:npt_flutter/util/export.dart';

class ProfileListImportButton extends StatelessWidget {
  const ProfileListImportButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const ElevatedButton(
      onPressed: Export.importProfiles,
      child: Text("Import Profile"),
    );
  }
}
