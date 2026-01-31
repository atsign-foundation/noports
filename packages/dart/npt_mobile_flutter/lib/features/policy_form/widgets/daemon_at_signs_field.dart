import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';

import '../../policy/models/policy.dart';
import 'at_signs_list_widget.dart';

class DaemonAtSignsField extends StatelessWidget {
  final RoleInProgress role;
  final bool isEditing;
  final Function(List<String>) onChanged;

  const DaemonAtSignsField({
    super.key,
    required this.role,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AtSignsListWidget(
      label: strings.deviceAtsigns,
      atSigns: role.daemonAtSigns,
      isEditing: isEditing,
      onChanged: onChanged,
      tooltip: strings.deviceAtsignDescriptionTwo,
    );
  }
}
