import 'package:at_onboarding_flutter/services/sdk_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../main.dart';
import '../../utils/at_error_dialog.dart';
import '../../utils/sizes.dart';
import 'settings_button.dart';

/// Custom reset button widget is to reset an atsign from keychain list,

class ResetAppButton extends StatefulWidget {
  final String? buttonText;
  final bool isOnboardingScreen;

  const ResetAppButton({
    Key? key,
    this.buttonText,
    this.isOnboardingScreen = false,
  }) : super(key: key);

  @override
  State<ResetAppButton> createState() => _ResetAppButtonState();
}

class _ResetAppButtonState extends State<ResetAppButton> {
  bool? loading = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnboardingScreen) {
      return SettingsButton(
        icon: Icons.restart_alt_outlined,
        title: 'Reset atsign',
        onTap: _showResetDialog,
      );
    } else {
      return TextButton(
          onPressed: _showResetDialog,
          child: Text(AppLocalizations.of(context)!.reset,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(fontSize: Sizes.p18, color: Colors.black, decoration: TextDecoration.underline)));
    }
  }

  Future<void> _showResetDialog() async {
    final strings = AppLocalizations.of(context)!;

    bool isSelectAtsign = false;
    bool isSelectAll = false;
    List<String>? atsignsList = await SDKService().getAtsignList();
    Map<String, bool?> atsignMap = <String, bool>{};
    if (atsignsList != null) {
      for (String atsign in atsignsList) {
        atsignMap[atsign] = false;
      }
    }
    if (mounted) {
      await showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(builder: (BuildContext context, void Function(void Function()) stateSet) {
              return AlertDialog(
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(strings.resetDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.normal,
                          )),
                      const SizedBox(
                        height: 10,
                      ),
                      const Divider(
                        thickness: 0.8,
                      )
                    ],
                  ),
                  content: atsignsList == null
                      ? Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                          Text(strings.noAtsignToReset,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.normal,
                              )),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(strings.closeButton,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color.fromARGB(255, 240, 94, 62),
                                      fontWeight: FontWeight.normal,
                                    ))),
                          )
                        ])
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              CheckboxListTile(
                                onChanged: (bool? value) {
                                  isSelectAll = value!;
                                  if (atsignMap.isNotEmpty) {
                                    atsignMap.updateAll((String? key, bool? value1) => value1 = value);
                                  }
                                  // atsignMap[atsign] = value;
                                  stateSet(() {});
                                },
                                value: isSelectAll,
                                checkColor: Colors.white,
                                activeColor: const Color.fromARGB(255, 240, 94, 62),
                                title: const Text('Select All',
                                    style: TextStyle(
                                      // fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    )),
                                // trailing: Checkbox,
                              ),
                              for (String atsign in atsignsList)
                                CheckboxListTile(
                                  onChanged: (bool? value) {
                                    if (atsignMap.isNotEmpty) {
                                      atsignMap[atsign] = value;
                                    }
                                    stateSet(() {});
                                  },
                                  value: atsignMap.isNotEmpty ? atsignMap[atsign] : true,
                                  checkColor: Colors.white,
                                  activeColor: const Color.fromARGB(255, 240, 94, 62),
                                  title: Text(atsign),
                                  // trailing: Checkbox,
                                ),
                              const Divider(thickness: 0.8),
                              if (isSelectAtsign)
                                Text(strings.resetErrorText,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                    )),
                              const SizedBox(
                                height: 10,
                              ),
                              Text(strings.resetWarningText,
                                  style: const TextStyle(
                                      // color: ColorConstants.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(
                                height: 10,
                              ),
                              Row(children: <Widget>[
                                TextButton(
                                  onPressed: () {
                                    Map<String, bool?> tempAtsignMap = <String, bool>{};
                                    tempAtsignMap.addAll(atsignMap);
                                    tempAtsignMap.removeWhere((String? key, bool? value) => value == false);
                                    if (tempAtsignMap.keys.toList().isEmpty) {
                                      isSelectAtsign = true;
                                      stateSet(() {});
                                    } else {
                                      isSelectAtsign = false;
                                      _resetDevice(tempAtsignMap.keys.toList());
                                    }
                                  },
                                  child: Text(strings.removeButton,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color.fromARGB(255, 240, 94, 62),
                                        fontWeight: FontWeight.normal,
                                      )),
                                ),
                                const Spacer(),
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text(strings.cancelButton,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black,
                                          fontWeight: FontWeight.normal,
                                        )))
                              ])
                            ],
                          ),
                        ));
            });
            // );
          });
    }
  }

  Future<void> _resetDevice(List<String> checkedAtsigns) async {
    Navigator.of(context).pop();
    setState(() {
      loading = true;
    });
    await SDKService().resetAtsigns(checkedAtsigns).then((void value) async {
      setState(() {
        loading = false;
      });

      List<String>? atsignsList = await SDKService().getAtsignList();
      if (atsignsList == null || atsignsList.length < 2) {
        if (mounted) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const MyApp(),
            ),
          );
        }
      }
    }).catchError((Object error) {
      setState(() {
        loading = false;
      });
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AtErrorDialog.getAlertDialog(error, context);
          });
    });
  }
}
