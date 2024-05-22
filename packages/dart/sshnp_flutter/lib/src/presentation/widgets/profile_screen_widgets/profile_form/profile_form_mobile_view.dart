import 'dart:developer';

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
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_dropdown_form_field.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_switch_widget.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/profile_form_card.dart';
import 'package:sshnp_flutter/src/presentation/widgets/ssh_key_management/ssh_key_management_form_dialog.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/form_validator.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../../../controllers/private_key_manager_controller.dart';

class ProfileFormMobileView extends ConsumerStatefulWidget {
  const ProfileFormMobileView({super.key});

  @override
  ConsumerState<ProfileFormMobileView> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileFormMobileView> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentConfigState currentProfile;
  SshnpPartialParams newConfig = SshnpPartialParams.empty();
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
    });
    super.initState();
  }

  void onSubmit(SshnpParams oldConfig, SshnpPartialParams newConfig) async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      final controller = ref.read(configFamilyController(newConfig.profileName ?? oldConfig.profileName!).notifier);
      bool rename = newConfig.profileName != null &&
          newConfig.profileName!.isNotEmpty &&
          oldConfig.profileName != null &&
          oldConfig.profileName!.isNotEmpty &&
          newConfig.profileName != oldConfig.profileName;
      SshnpParams config = SshnpParams.merge(oldConfig, newConfig);

      if (rename) {
        await controller.deleteConfig(context: context);
        // delete old config file and write the new one
        if (mounted) {
          await controller.putConfig(config, oldProfileName: oldConfig.profileName!, context: context);
        }
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
    final atSshKeyPairs = ref.watch(atPrivateKeyManagerListController);

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
                  CustomTextFormField(
                    width: double.infinity,
                    initialValue: oldConfig.profileName,
                    labelText: strings.profileName('required'),
                    onChanged: (value) {
                      newConfig = SshnpPartialParams.merge(
                        newConfig,
                        SshnpPartialParams(profileName: value),
                      );
                      ref.read(formProfileNameController.notifier).state = value;
                      log(ref.read(formProfileNameController));
                    },
                    validator: FormValidator.validateProfileNameField,
                  ),
                  gapH10,
                  CustomTextFormField(
                    width: double.infinity,
                    initialValue: oldConfig.device,
                    labelText: strings.device,
                    onSaved: (value) => newConfig = SshnpPartialParams.merge(
                      newConfig,
                      SshnpPartialParams(device: value),
                    ),
                  ),
                  gapH10,
                  CustomTextFormField(
                    width: double.infinity,
                    initialValue: oldConfig.srvdAtSign,
                    labelText: strings.host,
                    onSaved: (value) => newConfig = SshnpPartialParams.merge(
                      newConfig,
                      SshnpPartialParams(sshnpdAtSign: value),
                    ),
                    validator: FormValidator.validateAtsignField,
                  ),
                  gapH10,
                  CustomTextFormField(
                    width: double.infinity,
                    initialValue: oldConfig.srvdAtSign,
                    labelText: strings.srvdAtsign,
                    onSaved: (value) => newConfig = SshnpPartialParams.merge(
                      newConfig,
                      SshnpPartialParams(srvdAtSign: value),
                    ),
                    validator: FormValidator.validateRequiredField,
                  ),
                  gapH20,
                  Text(strings.sshKeyManagement('yes'), style: Theme.of(context).textTheme.bodyLarge),
                  gapH16,
                  ProfileFormCard(formFields: [
                    atSshKeyPairs.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(child: Text(error.toString())),
                        data: (atSshKeyPairs) {
                          final atSshKeyPairsList = atSshKeyPairs.toList();
                          atSshKeyPairsList.add(kPrivateKeyDropDownOption);
                          return CustomDropdownFormField<String>(
                            width: double.infinity,
                            initialValue: oldConfig.identityFile,
                            label: strings.privateKey,
                            hintText: strings.select,
                            items: atSshKeyPairsList.map((e) {
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
                            onChanged: (value) {
                              if (value == kPrivateKeyDropDownOption) {
                                showDialog(
                                    context: context, builder: ((context) => const SSHKeyManagementFormDialog()));
                              }
                            },
                            onSaved: (value) {
                              final atSshKeyPair = ref.read(privateKeyManagerFamilyController(value!));
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
                    gapH10,
                    CustomDropdownFormField<SupportedSshAlgorithm>(
                      width: double.infinity,
                      label: strings.sshAlgorithm,
                      hintText: strings.select,
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
                          width: double.infinity,
                          initialValue: oldConfig.remoteUsername ?? '',
                          labelText: strings.remoteUsername,
                          onSaved: (value) {
                            newConfig = SshnpPartialParams.merge(
                              newConfig,
                              SshnpPartialParams(remoteUsername: value),
                            );
                          }),
                      gapH10,
                      CustomTextFormField(
                        width: double.infinity,
                        initialValue: oldConfig.localPort.toString(),
                        labelText: strings.localPort,
                        onChanged: (value) => newConfig = SshnpPartialParams.merge(
                          newConfig,
                          SshnpPartialParams(localPort: int.tryParse(value)),
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
                        width: double.infinity,
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
                        width: double.infinity,
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
                          onPressed: () => onSubmit(oldConfig, newConfig),
                          child: Text(
                            strings.submit,
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                  color: Colors.white,
                                ),
                          ),
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
