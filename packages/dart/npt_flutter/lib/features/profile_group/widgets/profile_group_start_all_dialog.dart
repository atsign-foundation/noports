import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

/// Lets the user choose which connections of a folder Start all starts.
/// Pops with the ones to skip, or null on cancel.
class ProfileGroupStartAllDialog extends StatefulWidget {
  final List<String> uuids;
  final Set<String> skipped;
  const ProfileGroupStartAllDialog({
    required this.uuids,
    required this.skipped,
    super.key,
  });

  @override
  State<ProfileGroupStartAllDialog> createState() =>
      _ProfileGroupStartAllDialogState();
}

class _ProfileGroupStartAllDialogState
    extends State<ProfileGroupStartAllDialog> {
  late final Set<String> _checked = widget.uuids
      .where((String uuid) => !widget.skipped.contains(uuid))
      .toSet();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    return AlertDialog(
      title: Text(strings.groupChooseStartAll),
      content: SizedBox(
        width: Sizes.p400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.groupChooseStartAllDescription),
            gapH10,
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final String uuid in widget.uuids)
                    CheckboxListTile(
                      key: Key('ProfileGroupStartAllDialog-$uuid'),
                      value: _checked.contains(uuid),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: BlocBuilder<ProfileBloc, ProfileState>(
                        bloc: cache.getProfileBloc(uuid),
                        builder: (BuildContext context, ProfileState state) =>
                            Text(
                              state is ProfileLoadedState
                                  ? state.profile.displayName
                                  : strings.profileStatusLoading,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ),
                      onChanged: (bool? checked) => setState(() {
                        if (checked ?? false) {
                          _checked.add(uuid);
                        } else {
                          _checked.remove(uuid);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColor.primaryColor),
          // Start all would have nothing to start.
          onPressed: _checked.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  widget.uuids
                      .where((String uuid) => !_checked.contains(uuid))
                      .toSet(),
                ),
          child: Text(strings.save),
        ),
      ],
    );
  }
}
