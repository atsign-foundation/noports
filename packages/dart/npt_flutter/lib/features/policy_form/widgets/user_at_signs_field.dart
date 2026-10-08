import 'package:at_client/at_client.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../policy/models/policy.dart';
import 'at_signs_list_widget.dart';

class UserAtsignsField extends StatelessWidget {
  final RoleInProgress role;
  final bool isEditing;
  final Function(List<Atsign>) onChanged;

  const UserAtsignsField({
    super.key,
    required this.role,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AtsignsListWidget(
      label: strings.atsignsUser,
      atsigns: role.userAtsigns,
      isEditing: isEditing,
      onChanged: onChanged,
      tooltip: strings.atsignsUserTooltip,
    );
  }
}
