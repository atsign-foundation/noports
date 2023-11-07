import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/form_controllers.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_dropdown_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_switch_widget.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/profile_form_card.dart';
import 'package:sshnp_gui/src/presentation/widgets/ssh_key_management/file_picker_field.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/form_validator.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key});

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentConfigState currentProfile;
  SSHNPPartialParams newConfig = SSHNPPartialParams.empty();
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
    });
    super.initState();
  }

  void onSubmit(SSHNPParams oldConfig, SSHNPPartialParams newConfig) async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      final controller = ref.read(configFamilyController(newConfig.profileName ?? oldConfig.profileName!).notifier);
      bool rename = newConfig.profileName != null &&
          newConfig.profileName!.isNotEmpty &&
          oldConfig.profileName != null &&
          oldConfig.profileName!.isNotEmpty &&
          newConfig.profileName != oldConfig.profileName;
      SSHNPParams config = SSHNPParams.merge(oldConfig, newConfig);

      if (rename) {
        // delete old config file and write the new one
        await controller.putConfig(config, oldProfileName: oldConfig.profileName!, context: context);
      } else {
        // create new config file
        await controller.putConfig(config, context: context);
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

    final asyncOldConfig = ref.watch(configFamilyController(currentProfile.profileName));

    return asyncOldConfig.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (oldConfig) {
          return SingleChildScrollView(
            child: Form(
              key: _formkey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.profileName,
                        labelText: strings.profileName,
                        onChanged: (value) {
                          newConfig = SSHNPPartialParams.merge(
                            newConfig,
                            SSHNPPartialParams(profileName: value),
                          );
                          ref.read(formProfileNameController.notifier).state = value;
                          log(ref.read(formProfileNameController));
                        },
                        validator: FormValidator.validateProfileNameField,
                      ),
                      gapW8,
                    ],
                  ),
                  gapH10,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.device,
                        labelText: strings.device,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(device: value),
                        ),
                      ),
                      gapW38,
                      CustomTextFormField(
                        initialValue: oldConfig.sshnpdAtSign,
                        labelText: strings.sshnpdAtSign,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(sshnpdAtSign: value),
                        ),
                        validator: FormValidator.validateAtsignField,
                      ),
                    ],
                  ),
                  gapH10,
                  CustomTextFormField(
                    initialValue: oldConfig.host,
                    labelText: strings.host,
                    onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                      newConfig,
                      SSHNPPartialParams(host: value),
                    ),
                    validator: FormValidator.validateRequiredField,
                  ),
                  gapH20,
                  Text(strings.sshKeyManagement, style: Theme.of(context).textTheme.titleMedium),
                  ProfileFormCard(formFields: [
                    FilePickerField(
                      initialValue: oldConfig.identityFile,
                    ),
                    gapH10,
                    CustomTextFormField(
                      labelText: 'SSH Key Password',
                      initialValue: oldConfig.identityPassphrase,
                      isPasswordField: true,
                      onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                        newConfig,
                        SSHNPPartialParams(identityPassphrase: value),
                      ),
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
                      onChanged: ((value) =>
                          newConfig = SSHNPPartialParams.merge(newConfig, SSHNPPartialParams(sshAlgorithm: value))),
                    ),
                    gapH10,
                    CustomSwitchWidget(
                        labelText: strings.sendSshPublicKey,
                        value: newConfig.sendSshPublicKey ?? oldConfig.sendSshPublicKey,
                        onChanged: (newValue) {
                          setState(() {
                            newConfig = SSHNPPartialParams.merge(
                              newConfig,
                              SSHNPPartialParams(sendSshPublicKey: newValue),
                            );
                          });
                        }),
                  ]),
                  gapH20,
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TODO replace this with a drop down of available keyPairs (and buttons to upload / generate a new one, and button to delete)
                      // CustomTextFormField(
                      //   initialValue: oldConfig.sendSshPublicKey,
                      //   labelText: strings.sendSshPublicKey,
                      //   onChanged: (value) =>
                      //       newConfig = SSHNPPartialParams.merge(
                      //     newConfig,
                      //     SSHNPPartialParams(sendSshPublicKey: value),
                      //   ),
                      // ),
                      gapW8,
                      // TODO replace this switch with a dropdown with options for SupportedSSHAlgorithm.values
                      // SizedBox(
                      //   width: CustomTextFormField.defaultWidth,
                      //   height: CustomTextFormField.defaultHeight,
                      //   child: Row(
                      //     children: [
                      //       Text(strings.rsa),
                      //       gapW8,
                      //       Switch(
                      //         value: newConfig.rsa ?? oldConfig.rsa,
                      //         onChanged: (newValue) {
                      //           setState(() {
                      //             newConfig = SSHNPPartialParams.merge(
                      //               newConfig,
                      //               SSHNPPartialParams(rsa: newValue),
                      //             );
                      //           });
                      //         },
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                  gapH10,
                  Text(strings.connectionConfiguration, style: Theme.of(context).textTheme.titleMedium),
                  gapH20,
                  ProfileFormCard(
                    formFields: [
                      CustomTextFormField(
                          initialValue: oldConfig.remoteUsername ?? '',
                          labelText: strings.remoteUserName,
                          onChanged: (value) {
                            newConfig = SSHNPPartialParams.merge(
                              newConfig,
                              SSHNPPartialParams(remoteUsername: value),
                            );
                          }),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.port.toString(),
                        labelText: strings.port,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(port: int.tryParse(value)),
                        ),
                        validator: FormValidator.validateRequiredField,
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.localPort.toString(),
                        labelText: strings.localPort,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(localPort: int.tryParse(value)),
                        ),
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.remoteSshdPort.toString(),
                        labelText: strings.remoteSshdPort,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(remoteSshdPort: int.tryParse(value)),
                        ),
                      ),
                      gapH12,
                    ],
                  ),
                  gapH20,
                  Text(strings.advancedConfiguration, style: Theme.of(context).textTheme.titleMedium),
                  gapH20,
                  ProfileFormCard(
                    formFields: [
                      CustomTextFormField(
                        initialValue: oldConfig.localSshOptions.join(','),
                        hintText: strings.localSshOptionsHint,
                        labelText: strings.localSshOptions,
                        //Double the width of the text field (+8 for the gapW8)
                        // width: kFieldDefaultWidth * 2 + 8,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(localSshOptions: value.split(',')),
                        ),
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.rootDomain,
                        labelText: strings.rootDomain,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(rootDomain: value),
                        ),
                      ),
                    ],
                  ),
                  gapH10,
                  SizedBox(
                    width: kFieldDefaultWidth + Sizes.p233,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () => onSubmit(oldConfig, newConfig),
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
