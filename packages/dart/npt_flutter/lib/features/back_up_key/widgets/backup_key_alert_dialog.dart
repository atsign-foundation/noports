import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BackupKeyAlertDialog extends StatefulWidget {
  const BackupKeyAlertDialog({super.key});

  @override
  State<BackupKeyAlertDialog> createState() => _BackupKeyAlertDialogState();
}

class _BackupKeyAlertDialogState extends State<BackupKeyAlertDialog> {
  bool visibility = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      content: Padding(
        padding: const EdgeInsets.all(Sizes.p20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.p16),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.download(PhosphorIconsStyle.bold),
                    color: Colors.black,
                  ),
                  gapW10,
                  Text(
                    strings.backUpAtKeys,
                    style: const TextStyle(
                        fontSize: Sizes.p18, color: Colors.black),
                    softWrap: false,
                  ),
                  const Spacer(),
                  Text(
                    strings.required,
                    style: const TextStyle(
                        color: AppColor.primaryColor, fontSize: Sizes.p16),
                  )
                ],
              ),
            ),
            gapH16,
            SizedBox(
              width: double.infinity,
              child: CustomContainer.background(
                child: Text.rich(
                  TextSpan(
                      text: strings.backUpAtKeysIntroMsgFirst,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: strings.backUpAtKeysIntroMsgLast,
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ]),
                ),
              ),
            ),
            gapH10,
            SizedBox(
              width: double.infinity,
              child: CustomContainer.background(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.info(),
                        color: AppColor.primaryColor,
                      ),
                      gapW14,
                      Text(strings.whatAreAtKeys,
                          style: const TextStyle(color: AppColor.primaryColor)),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            visibility = !visibility;
                          });
                        },
                        icon: Icon(PhosphorIcons.caretDown()),
                        color: AppColor.primaryColor,
                      )
                    ],
                  ),
                  gapH14,
                  Visibility(
                    maintainAnimation: true,
                    maintainState: true,
                    visible: visibility,
                    child: Text(
                      strings.backUpAtKeysMainMsg,
                    ),
                  ),
                ],
              )),
            ),
            gapH10,
            CustomContainer.background(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await context.read<BackupKeyCubit>().backUpKeys();
                  },
                  child: Text(strings.saveAtKeys),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}
