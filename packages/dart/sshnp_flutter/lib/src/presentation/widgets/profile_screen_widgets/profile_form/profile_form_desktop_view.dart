import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_flutter/src/controllers/config_controller.dart';
import 'package:sshnp_flutter/src/controllers/form_controllers.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_flutter/src/controllers/profile_private_key_manager_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_dropdown_form_field.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_switch_widget.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/profile_form_card.dart';
import 'package:sshnp_flutter/src/presentation/widgets/ssh_key_management/ssh_key_management_form_dialog.dart';
import 'package:sshnp_flutter/src/repository/profile_private_key_manager_repository.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/form_validator.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../../../application/profile_private_key_manager.dart';
import '../../../../controllers/private_key_manager_controller.dart';

class ProfileFormDesktopView extends ConsumerStatefulWidget {
  const ProfileFormDesktopView({super.key});

  @override
  ConsumerState<ProfileFormDesktopView> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileFormDesktopView> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentConfigState currentProfile;
  String? privateKeyNickname;
  SshnpPartialParams newConfig = SshnpPartialParams.empty();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
      privateKeyNickname =
          await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(currentProfile.profileName)
              .then((value) => value.privateKeyNickname);

      if (privateKeyNickname == '') privateKeyNickname = null;
    });

    super.initState();
  }

  void onSubmit(SshnpParams oldConfig) async {
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

    final asyncOldConfig = ref.watch(configFamilyController(currentProfile.profileName));

    return asyncOldConfig.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (oldConfig) {
          return SingleChildScrollView(
            child: Form(
              key: _formkey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.profileName,
                        labelText: strings.profileName,
                        toolTip: strings.profileNameTooltip,
                        onSaved: (value) {
                          oldConfig.idleTimeout;
                          newConfig = SshnpPartialParams.merge(
                            newConfig,
                            SshnpPartialParams(profileName: value!),
                          );
                          ref.read(formProfileNameController.notifier).state = value;
                        },
                        validator: FormValidator.validateProfileNameField,
                      ),
                      gapW38,
                      CustomTextFormField(
                        initialValue: oldConfig.host,
                        labelText: strings.host,
                        toolTip: strings.hostTooltip,
                        onSaved: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(host: value),
                        ),
                        validator: FormValidator.validateAtsignField,
                      ),
                    ],
                  ),
                  gapH10,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextFormField(
                          initialValue: oldConfig.device,
                          labelText: strings.device,
                          toolTip: strings.deviceTooltip,
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
                        toolTip: strings.sshnpdAtSignTooltip,
                        onSaved: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(sshnpdAtSign: value),
                        ),
                        validator: FormValidator.validateAtsignField,
                      ),
                    ],
                  ),
                  gapH20,
                  Text(strings.connectionConfiguration, style: Theme.of(context).textTheme.bodyLarge),
                  gapH20,
                  ProfileFormCard(
                    largeScreenRightPadding: Sizes.p32,
                    formFields: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTextFormField(
                              initialValue: oldConfig.remoteUsername,
                              labelText: strings.remoteUserName,
                              toolTip: strings.remoteUserNameTooltip,
                              onSaved: (value) {
                                if (value == '') {
                                  value = null;
                                }
                                newConfig = SshnpPartialParams.merge(
                                  newConfig,
                                  SshnpPartialParams(remoteUsername: value),
                                );
                              }),
                          gapW38,
                          CustomTextFormField(
                              initialValue: oldConfig.tunnelUsername,
                              labelText: strings.tunnelUserName,
                              toolTip: strings.tunnelUserNameTooltip,
                              onSaved: (value) {
                                if (value == '') {
                                  value = null;
                                }
                                newConfig = SshnpPartialParams.merge(
                                  newConfig,
                                  SshnpPartialParams(tunnelUsername: value),
                                );
                              }),
                        ],
                      ),
                      gapH10,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTextFormField(
                            initialValue: oldConfig.remoteSshdPort.toString(),
                            labelText: strings.remoteSshdPort,
                            toolTip: strings.remoteSshdPortTooltip,
                            onSaved: (value) => newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(remoteSshdPort: int.tryParse(value!)),
                            ),
                            validator: FormValidator.validateRequiredPortField,
                          ),
                          gapW38,
                          CustomTextFormField(
                            initialValue: oldConfig.localPort.toString(),
                            labelText: strings.localPort,
                            toolTip: strings.localPortTooltip,
                            onSaved: (value) => newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(localPort: int.tryParse(value!)),
                            ),
                            validator: FormValidator.validateRequiredPortField,
                          ),
                        ],
                      ),
                      gapH12,
                    ],
                  ),
                  gapH20,
                  Text(strings.sshKeyManagement('yes'), style: Theme.of(context).textTheme.bodyLarge),
                  gapH16,
                  ProfileFormCard(largeScreenRightPadding: Sizes.p32, formFields: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        privateKeyManagerListController.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(child: Text(error.toString())),
                            data: (privateKeyListData) {
                              final privateKeyList = privateKeyListData.toList();
                              privateKeyList.add(kPrivateKeyDropDownOption);
                              return CustomDropdownFormField<String>(
                                width: kFieldDefaultWidth + Sizes.p10,
                                initialValue: privateKeyNickname,
                                label: strings.privateKey,
                                hintText: strings.select,
                                tooltip: strings.privateKeyTooltip,
                                items: privateKeyList.map((e) {
                                  if (e == kPrivateKeyDropDownOption) {
                                    return DropdownMenuItem<String>(
                                      value: e,
                                      child: DottedBorder(
                                        dashPattern: const [10, 10],
                                        color: kPrimaryColor,
                                        radius: const Radius.circular(2),
                                        padding: const EdgeInsets.all(Sizes.p12),
                                        child: Text(
                                          e,
                                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: kPrimaryColor),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    );
                                  }
                                }).toList(),
                                onChanged: (value) async {
                                  if (value == kPrivateKeyDropDownOption) {
                                    privateKeyNickname = await showDialog(
                                        context: context, builder: ((context) => const SSHKeyManagementFormDialog()));
                                  }
                                },
                                onSaved: (value) {
                                  final profilePrivateKeyManager = ProfilePrivateKeyManager(
                                    profileNickname: newConfig.profileName!,
                                    privateKeyNickname: value!,
                                  );
                                  final privateProfileController = ref.watch(
                                      profilePrivateKeyManagerFamilyController(profilePrivateKeyManager.identifier)
                                          .notifier);
                                  privateProfileController.saveProfilePrivateKeyManager(
                                      profilePrivateKeyManager: profilePrivateKeyManager);
                                },
                                onValidator: FormValidator.validatePrivateKeyField,
                              );
                            }),
                        gapW38,
                        CustomSwitchWidget(
                          labelText: strings.sendSshPublicKey,
                          value: newConfig.sendSshPublicKey ?? oldConfig.sendSshPublicKey,
                          tooltip: strings.sendSshPublicKeyTooltip,
                          onChanged: (newValue) {
                            setState(() {
                              newConfig = SshnpPartialParams.merge(
                                newConfig,
                                SshnpPartialParams(sendSshPublicKey: newValue),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ]),
                  gapH20,
                  Text(strings.advancedConfiguration, style: Theme.of(context).textTheme.bodyLarge),
                  gapH20,
                  ProfileFormCard(
                    largeScreenRightPadding: Sizes.p32,
                    formFields: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTextFormField(
                            initialValue: oldConfig.localSshOptions.join(','),
                            hintText: strings.localSshOptionsHint,
                            labelText: strings.localSshOptions,
                            toolTip: strings.localSshOptionsTooltip,
                            onSaved: (value) => newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(localSshOptions: value?.split(',')),
                            ),
                          ),
                          gapW38,
                          CustomTextFormField(
                            initialValue: oldConfig.rootDomain,
                            labelText: strings.rootDomain,
                            toolTip: strings.rootDomainTooltip,
                            onSaved: (value) => newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(rootDomain: value),
                            ),
                            validator: FormValidator.validateRequiredField,
                          ),
                        ],
                      ),
                    ],
                  ),
                  gapH20,
                  Text(strings.socketRendezvousConfiguration, style: Theme.of(context).textTheme.bodyLarge),
                  gapH20,
                  ProfileFormCard(
                    largeScreenRightPadding: Sizes.p32,
                    formFields: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomSwitchWidget(
                            labelText: strings.authenticateClientToRvd,
                            value: newConfig.authenticateClientToRvd ?? oldConfig.authenticateClientToRvd,
                            tooltip: strings.authenticateClientToRvdTooltip,
                            onChanged: (newValue) {
                              setState(() {
                                newConfig = SshnpPartialParams.merge(
                                  newConfig,
                                  SshnpPartialParams(authenticateClientToRvd: newValue),
                                );
                              });
                            },
                          ),
                          gapW38,
                          CustomSwitchWidget(
                            labelText: strings.authenticateDeviceToRvd,
                            value: newConfig.authenticateDeviceToRvd ?? oldConfig.authenticateDeviceToRvd,
                            tooltip: strings.authenticateDeviceToRvdTooltip,
                            onChanged: (newValue) {
                              setState(() {
                                newConfig = SshnpPartialParams.merge(
                                  newConfig,
                                  SshnpPartialParams(authenticateDeviceToRvd: newValue),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      gapH10,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomSwitchWidget(
                            labelText: strings.encryptRvdTraffic,
                            value: newConfig.encryptRvdTraffic ?? oldConfig.encryptRvdTraffic,
                            tooltip: strings.encryptRvdTrafficTooltip,
                            onChanged: (newValue) {
                              setState(() {
                                newConfig = SshnpPartialParams.merge(
                                  newConfig,
                                  SshnpPartialParams(encryptRvdTraffic: newValue),
                                );
                              });
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  gapH30,
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
                  gapH30,
                ],
              ),
            ),
          );
        });
  }
}
