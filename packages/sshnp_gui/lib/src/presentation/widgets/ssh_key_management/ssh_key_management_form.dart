import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/form_controllers.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_gui/src/controllers/ssh_key_pair_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_dropdown_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_switch_widget.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/ssh_key_management/file_picker_field.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/form_validator.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

import '../profile_form/profile_form_card.dart';

class SSHKeyManagementForm extends ConsumerStatefulWidget {
  const SSHKeyManagementForm({super.key});

  @override
  ConsumerState<SSHKeyManagementForm> createState() => _SSHKeyManagementFormState();
}

class _SSHKeyManagementFormState extends ConsumerState<SSHKeyManagementForm> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentConfigState currentProfile;
  AtSSHKeyPair newAtSSHKeyPair = AtSSHKeyPair.empty();
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
    });
    super.initState();
  }

  void onSubmit(AtSSHKeyPair oldKeyPair, AtSSHKeyPair newKeyPair) async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      final controller = ref.read(atSSHKeyPairFamilyController(newKeyPair.identifier).notifier);

      bool rename = newKeyPair.identifier == oldKeyPair.identifier;

      if (rename) {
        // delete old config file and write the new one
        await controller.deleteAtSSHKeyPair(identifier: newKeyPair.identifier);
        await controller.saveAtSSHKeyPair(atSSHKeyPair: newKeyPair);
      } else {
        // create new config file
        await controller.saveAtSSHKeyPair(atSSHKeyPair: newKeyPair);
      }
      if (mounted) {
        ref.read(navigationRailController.notifier).setRoute(AppRoute.home);
        context.pushReplacementNamed(AppRoute.home.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    currentProfile = ref.watch(currentConfigController);

    final asyncOldConfig = ref.watch(atSSHKeyPairFamilyController(currentProfile.profileName));

    return asyncOldConfig.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (oldAtSSHKeyPair) {
          return SingleChildScrollView(
            child: Form(
              key: _formkey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  gapH20,
                  Text(strings.sshKeyManagement, style: Theme.of(context).textTheme.titleMedium),
                  ProfileFormCard(formFields: [
                    CustomTextFormField(
                      initialValue: oldAtSSHKeyPair.identifier,
                      labelText: strings.nickName,
                      onChanged: (value) {
                        newAtSSHKeyPair.identifier = newAtSSHKeyPair.identifier;
                        ref.read(formProfileNameController.notifier).state = value;
                        log(ref.read(formProfileNameController));
                      },
                      validator: FormValidator.validateProfileNameField,
                    ),
                    gapH10,
                    FilePickerField(
                      initialValue: oldAtSSHKeyPair.identifier,
                    ),
                    gapH10,
                    const CustomTextFormField(
                      labelText: 'SSH Key Password',
                      // TODO Fix this
                      // initialValue: oldAtSSHKeyPair.identityPassphrase,
                      isPasswordField: true,
                      // onChanged: (value) => newAtSSHKeyPair.identityPassPhrase = newAtSSHKeyPair.identityPassPhrase,
                    ),
                    gapH10,
                    CustomDropdownFormField<SupportedSSHAlgorithm>(
                      label: strings.sshAlgorithm,
                      hintText: strings.select,
                      items: SupportedSSHAlgorithm.values
                          .map((e) => DropdownMenuItem<SupportedSSHAlgorithm>(
                                value: e,
                                child: Text(e.name),
                              ))
                          .toList(),
                      // TODO Fix this
                      // onChanged: ((value) => newAtSSHKeyPair =
                      //     SSHNPPartialParams.merge(newAtSSHKeyPair, SSHNPPartialParams(sshAlgorithm: value))
                      //     ),
                    ),
                    gapH10,
                    CustomSwitchWidget(
                      labelText: strings.sendSshPublicKey,
                      // TODO Fix this
                      value: false,
                      onChanged: (a) {},
                      // value: newAtSSHKeyPair.sendSshPublicKey ?? oldAtSSHKeyPair.sendSshPublicKey,
                      // onChanged: (newValue) {
                      //   setState(() {
                      //     newAtSSHKeyPair = SSHNPPartialParams.merge(
                      //       newAtSSHKeyPair,
                      //       SSHNPPartialParams(sendSshPublicKey: newValue),
                      //     );
                      //   });
                      // }
                    ),
                  ]),
                  gapH20,
                  gapH10,
                  SizedBox(
                    width: kFieldDefaultWidth + Sizes.p233,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () => onSubmit(oldAtSSHKeyPair, newAtSSHKeyPair),
                          child: Text(strings.connect),
                        ),
                        gapW8,
                        TextButton(
                          onPressed: () {
                            ref.read(navigationRailController.notifier).setRoute(AppRoute.home);
                            context.pushReplacementNamed(AppRoute.home.name);
                          },
                          child: Text(strings.cancel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
