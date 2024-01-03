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
import 'package:sshnp_gui/src/controllers/profile_private_key_manager_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_form/custom_dropdown_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_form/custom_switch_widget.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_form/profile_form_card.dart';
import 'package:sshnp_gui/src/presentation/widgets/ssh_key_management/ssh_key_management_form_dialog.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/form_validator.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

import '../../../../application/profile_private_key_manager.dart';
import '../../../../controllers/private_key_manager_controller.dart';
import 'custom_multiselect_chip_form_field.dart';

class ProfileFormDesktopView extends ConsumerStatefulWidget {
  const ProfileFormDesktopView({super.key});

  @override
  ConsumerState<ProfileFormDesktopView> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileFormDesktopView> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentConfigState currentProfile;
  SshnpPartialParams newConfig = SshnpPartialParams.empty();
  List<String> selectedItems = [];
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
    });
    super.initState();
  }

  void onSubmit(SshnpParams oldConfig) async {
    log('on submit start ${selectedItems.toString()}');
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      SshnpParams config = SshnpParams.merge(oldConfig, newConfig);

      // get the controller for the profile that is about to be saved. Since this profile is not saved a log will be printed stating that the profile does not exist in keystore.
      final controller = ref.read(configFamilyController(newConfig.profileName!).notifier);
      bool rename = newConfig.profileName != null &&
          newConfig.profileName!.isNotEmpty &&
          oldConfig.profileName != null &&
          oldConfig.profileName!.isNotEmpty &&
          newConfig.profileName != oldConfig.profileName;

      if (rename) {
        // delete old config and create new config file
        await controller.putConfig(config, oldProfileName: oldConfig.profileName!, context: context);
      } else {
        // create new config file without trying to delete the old config file
        await controller.putConfig(config, context: context);
      }

      /// Save the profile private key manager to the device's secure storage
      // TODO: Add a check to see if the profile private key manager already exists in the secure storage
      log('selected items are $selectedItems just before for loop');
      for (final item in selectedItems) {
        final profilePrivateKeyManager = ProfilePrivateKeyManager(
          profileNickname: newConfig.profileName!,
          privateKeyNickname: item,
        );
        final privateProfileController =
            ref.watch(profilePrivateKeyManagerFamilyController(profilePrivateKeyManager.identifier).notifier);
        privateProfileController.saveProfilePrivateKeyManager(profilePrivateKeyManager: profilePrivateKeyManager);
        log('for loop completed');
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
    final privateKeyManagerListController = ref.watch(atPrivateKeyManagerListController);
    final profilePrivateKeyListController = ref.watch(profilePrivateKeyManagerListController);

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
                        onSaved: (value) {
                          newConfig = SshnpPartialParams.merge(
                            newConfig,
                            SshnpPartialParams(profileName: value!),
                          );
                          ref.read(formProfileNameController.notifier).state = value;
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
                          onSaved: (value) {
                            newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(device: value!),
                            );
                          }),
                      gapW38,
                      CustomTextFormField(
                        initialValue: oldConfig.sshnpdAtSign,
                        labelText: strings.sshnpdAtSign,
                        onSaved: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(sshnpdAtSign: value),
                        ),
                        validator: FormValidator.validateAtsignField,
                      ),
                    ],
                  ),
                  gapH10,
                  CustomTextFormField(
                    initialValue: oldConfig.host,
                    labelText: strings.host,
                    onSaved: (value) => newConfig = SshnpPartialParams.merge(
                      newConfig,
                      SshnpPartialParams(host: value),
                    ),
                    validator: FormValidator.validateRequiredField,
                  ),
                  gapH20,
                  Text(strings.sshKeyManagement('yes'), style: Theme.of(context).textTheme.bodyLarge),
                  gapH16,
                  ProfileFormCard(largeScreenRightPadding: 5, formFields: [
                    privateKeyManagerListController.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(child: Text(error.toString())),
                        data: (privateKeyList) {
                          profilePrivateKeyListController.when(
                              data: ((data) {
                                // TODO: Might have to filter for matching profiles.
                                selectedItems = data.map((e) => e.split('-')[1]).toList();
                              }),
                              error: (error, stack) => Center(child: Text(error.toString())),
                              loading: () => const Center(child: CircularProgressIndicator()));
                          return CustomMultiSelectChipFormField<String>(
                            width: kFieldDefaultWidth + Sizes.p5,
                            selectedItems: selectedItems,
                            label: strings.privateKey,
                            hintText: strings.select,
                            items: privateKeyList.toList(),
                            onChanged: (value) {
                              if (value == kPrivateKeyDropDownOption) {
                                showDialog(
                                    context: context, builder: ((context) => const SSHKeyManagementFormDialog()));
                              }
                            },
                            onSaved: (value) {
                              final atSshKeyPair = ref.read(privateKeyManagerFamilyController(value!));
                              // write to a new controller to map the profile name to the ssh key pair manager nickname. Store this information locally.

                              // At the point of ssh connect the profile name and the key manager name so get the identity passphrase and the fiel content.
                              atSshKeyPair.when(
                                  data: (data) => newConfig = SshnpPartialParams.merge(
                                      newConfig,
                                      SshnpPartialParams(
                                          identityFile: data.nickname, identityPassphrase: data.passPhrase)),
                                  error: ((error, stackTrace) => log(error.toString())),
                                  loading: () => const CircularProgressIndicator());
                            },
                            onValidator: FormValidator.validatePrivateKeyField,
                          );
                        }),
                    gapH20,
                    // TODO: Add key management dropdown here
                    gapH20,

                    CustomDropdownFormField<SupportedSshAlgorithm>(
                      label: strings.sshAlgorithm,
                      hintText: strings.select,
                      initialValue: oldConfig.sshAlgorithm,
                      items: SupportedSshAlgorithm.values
                          .map((e) => DropdownMenuItem<SupportedSshAlgorithm>(
                                value: e,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: ((value) =>
                          newConfig = SshnpPartialParams.merge(newConfig, SshnpPartialParams(sshAlgorithm: value))),
                    ),
                    gapH10,
                    CustomSwitchWidget(
                        //TODO: change string to sendSshPublicKey not ssh public key
                        labelText: strings.sendSshPublicKey,
                        value: newConfig.sendSshPublicKey ?? oldConfig.sendSshPublicKey,
                        onChanged: (newValue) {
                          setState(() {
                            newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(sendSshPublicKey: newValue),
                            );
                          });
                        }),
                  ]),
                  gapH30,
                  Text(strings.connectionConfiguration, style: Theme.of(context).textTheme.bodyLarge),
                  gapH20,
                  ProfileFormCard(
                    formFields: [
                      CustomTextFormField(
                          initialValue: oldConfig.remoteUsername ?? '',
                          labelText: strings.remoteUserName,
                          onSaved: (value) {
                            newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(remoteUsername: value),
                            );
                          }),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.port.toString(),
                        labelText: strings.port,
                        onChanged: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(port: int.tryParse(value)),
                        ),
                        validator: FormValidator.validateRequiredField,
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.localPort.toString(),
                        labelText: strings.localPort,
                        onChanged: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(localPort: int.tryParse(value)),
                        ),
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.localSshdPort.toString(),
                        labelText: strings.localSshdPort,
                        onChanged: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(localSshdPort: int.tryParse(value)),
                        ),
                      ),
                      gapH12,
                    ],
                  ),
                  gapH20,
                  Text(strings.advancedConfiguration, style: Theme.of(context).textTheme.bodyMedium),
                  gapH20,
                  ProfileFormCard(
                    formFields: [
                      CustomTextFormField(
                        initialValue: oldConfig.localSshOptions.join(','),
                        hintText: strings.localSshOptionsHint,
                        labelText: strings.localSshOptions,
                        //Double the width of the text field (+8 for the gapW8)
                        // width: kFieldDefaultWidth * 2 + 8,
                        onChanged: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(localSshOptions: value.split(',')),
                        ),
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: oldConfig.rootDomain,
                        labelText: strings.rootDomain,
                        onSaved: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(rootDomain: value),
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
                          onPressed: () {
                            onSubmit(oldConfig);
                          },
                          child: Text(strings.submit),
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
