import 'package:flutter/material.dart';
import '../../policy/models/policy.dart';
import 'at_signs_list_widget.dart';

class DaemonAtSignsField extends StatelessWidget {
  final RoleInProgress role;
  final bool isEditing;
  final Function(List<String>) onChanged;

  const DaemonAtSignsField({super.key, required this.role, required this.isEditing, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AtSignsListWidget(
      label: 'Device atSigns',
      atSigns: role.daemonAtSigns,
      isEditing: isEditing,
      onChanged: onChanged,
      tooltip: 'An atSign like "@bob_device" that will be connected to. This is also known as the daemon or npd machine that is running the daemon process that will be receiving connection requests where connections will be established to this device.',
    );
  }
}