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
  AtSshKeyPair newAtSshKeyPair = AtSshKeyPair.empty();
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
    });
    super.initState();
  }

  void onSubmit(AtSshKeyPair oldKeyPair, AtSshKeyPair newKeyPair) async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      final controller = ref.read(atSSHKeyPairFamilyController(newKeyPair.identifier).notifier);

      bool rename = newKeyPair.identifier == oldKeyPair.identifier;

      if (rename) {
        // delete old config file and write the new one
        await controller.deleteAtSshKeyPair(identifier: newKeyPair.identifier);
        await controller.saveAtSshKeyPair(atSSHKeyPair: newKeyPair);
      } else {
        // create new config file
        await controller.saveAtSshKeyPair(atSSHKeyPair: newKeyPair);
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
        data: (oldAtSshKeyPair) {
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
                      initialValue: oldAtSshKeyPair.identifier,
                      labelText: strings.nickName,
                      onChanged: (value) {
                        newAtSshKeyPair.identifier = newAtSshKeyPair.identifier;
                        ref.read(formProfileNameController.notifier).state = value;
                        log(ref.read(formProfileNameController));
                      },
                      validator: FormValidator.validateProfileNameField,
                    ),
                    gapH10,
                    FilePickerField(
                      initialValue: oldAtSshKeyPair.identifier,
                    ),
                    gapH10,
                    const CustomTextFormField(
                      labelText: 'SSH Key Password',
                      // TODO Fix this
                      // initialValue: oldAtSshKeyPair.identityPassphrase,
                      isPasswordField: true,
                      // onChanged: (value) => newAtSshKeyPair.identityPassPhrase = newAtSshKeyPair.identityPassPhrase,
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
                      // onChanged: ((value) => newAtSshKeyPair =
                      //     SSHNPPartialParams.merge(newAtSshKeyPair, SSHNPPartialParams(sshAlgorithm: value))
                      //     ),
                    ),
                    gapH10,
                    CustomSwitchWidget(
                      labelText: strings.sendSshPublicKey,
                      // TODO Fix this
                      value: false,
                      onChanged: (a) {},
                      // value: newAtSshKeyPair.sendSshPublicKey ?? oldAtSshKeyPair.sendSshPublicKey,
                      // onChanged: (newValue) {
                      //   setState(() {
                      //     newAtSshKeyPair = SSHNPPartialParams.merge(
                      //       newAtSshKeyPair,
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
                          onPressed: () => onSubmit(oldAtSshKeyPair, newAtSshKeyPair),
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
