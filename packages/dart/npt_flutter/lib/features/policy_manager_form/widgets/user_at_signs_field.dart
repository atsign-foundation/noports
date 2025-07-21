import 'package:flutter/material.dart';
import '../../policy_manager/models/policy.dart';
import 'at_signs_list_widget.dart';

class UserAtSignsField extends StatelessWidget {
  final Role role;
  final bool isEditing;
  final Function(List<String>) onChanged;

  const UserAtSignsField({super.key, required this.role, required this.isEditing, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AtSignsListWidget(
      label: 'User atSigns',
      atSigns: role.userAtSigns,
      isEditing: isEditing,
      onChanged: onChanged,
      tooltip: 'An atSign like "@alice" that will be connecting to other devices',
    );
  }
}