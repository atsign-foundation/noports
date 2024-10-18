import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../routes.dart';
import '../../../util/export.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../widgets/multi_select_dialog.dart';

class ProfilePopupMenuButton extends StatelessWidget {
  const ProfilePopupMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final state = context.watch<ProfileBloc>().state;
    final isDisableIcons = state is ProfileStarting || state is ProfileStarted || state is ProfileStopping;
    return PopupMenuButton<PopupMenuEntry>(
        padding: EdgeInsets.zero,
        itemBuilder: (_) {
          return [
            PopupMenuItem(
              child: Row(
                children: [
                  PhosphorIcon(PhosphorIcons.pencil()),
                  gapW10,
                  Text(strings.edit),
                ],
              ),
              onTap: () {
                if (state is! ProfileLoadedState) return;
                if (isDisableIcons) {
                  CustomSnackBar.notification(content: strings.profileRunningActionDeniedMessage);
                  return;
                }

                if (context.mounted) {
                  Navigator.of(context).pushNamed(Routes.profileForm, arguments: state.profile.uuid);
                }
              },
            ),
            PopupMenuItem(
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.export()),
                    gapW10,
                    Text(strings.export),
                  ],
                ),
                onTap: () {
                  var state = context.read<ProfileBloc>().state;
                  if (state is! ProfileLoadedState) return;

                  var json = state.profile.toExportableJson();

                  showDialog(
                      context: context,
                      builder: (BuildContext context) => MultiSelectDialog(strings.profileExportMessage, {
                            strings.json: Export.getExportCallback(ExportableProfileFiletype.json, [json]),
                            strings.yaml: Export.getExportCallback(ExportableProfileFiletype.yaml, [json]),
                          }));
                }),
            PopupMenuItem(
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.arrowClockwise()),
                    gapW10,
                    Text(strings.refresh),
                  ],
                ),
                onTap: () {
                  context.read<ProfileBloc>().add(const ProfileLoadEvent(useCache: false));
                }),
            PopupMenuItem(
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.trash()),
                    gapW10,
                    Text(strings.delete),
                  ],
                ),
                onTap: () {
                  if (isDisableIcons) {
                    CustomSnackBar.notification(content: strings.profileRunningActionDeniedMessage);
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ConfirmationDialog(
                          message: strings.profileDeleteMessage,
                          actionText: strings.delete,
                          action: () {
                            var state = context.read<ProfileBloc>().state;
                            if (state is! ProfileLoadedState) return;
                            App.navState.currentContext
                                ?.read<ProfileListBloc>()
                                .add(ProfileListDeleteEvent(toDelete: [state.uuid]));
                          });
                    },
                  );
                })
          ];
        });
  }
}
