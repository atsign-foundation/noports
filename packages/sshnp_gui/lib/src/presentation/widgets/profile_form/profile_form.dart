import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/nav_route_controller.dart';
import 'package:sshnp_gui/src/controllers/sshnp_params_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/enum.dart';
import 'package:sshnp_gui/src/utils/sizes.dart';
import 'package:sshnp_gui/src/utils/validator.dart';

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key});

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentSSHNPParamsModel currentProfile;
  SSHNPPartialParams newConfig = SSHNPPartialParams.empty();
  @override
  void initState() {
    super.initState();
  }

  void onSubmit(SSHNPParams oldConfig, SSHNPPartialParams newConfig) async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      final controller =
          ref.read(sshnpParamsFamilyController(newConfig.profileName ?? oldConfig.profileName!).notifier);
      bool overwrite = currentProfile.configFileWriteState == ConfigFileWriteState.update;
      bool rename = newConfig.profileName.isNotNull &&
          newConfig.profileName!.isNotEmpty &&
          oldConfig.profileName.isNotNull &&
          oldConfig.profileName!.isNotEmpty &&
          newConfig.profileName != oldConfig.profileName;
      SSHNPParams config = SSHNPParams.merge(oldConfig, newConfig);
      if (rename) {
        // delete old config file and write the new one
        await ref.read(sshnpParamsFamilyController(oldConfig.profileName!).notifier).delete();
        await controller.create(config);
      } else if (overwrite) {
        // overwrite the existing file
        await controller.edit(config);
      } else {
        // create new config file
        await controller.create(config);
      }
      if (context.mounted) {
        ref.read(navRouteController.notifier).goTo(AppRoute.home);
        context.pushReplacementNamed(AppRoute.home.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    currentProfile = ref.watch(sshnpParamsController);

    final asyncOldConfig = ref.watch(sshnpParamsFamilyController(currentProfile.profileName));
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
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.profileName ?? '',
                        labelText: strings.profileName,
                        onChanged: (value) {
                          newConfig = SSHNPPartialParams.merge(
                            newConfig,
                            SSHNPPartialParams(profileName: value),
                          );
                        },
                        validator: Validator.validateRequiredField,
                      ),
                      gapW8,
                      CustomTextFormField(
                        initialValue: oldConfig.device,
                        labelText: strings.device,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(device: value),
                        ),
                      ),
                    ],
                  ),
                  gapH10,
                  Row(
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.sshnpdAtSign ?? '',
                        labelText: strings.sshnpdAtSign,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(sshnpdAtSign: value),
                        ),
                        validator: Validator.validateAtsignField,
                      ),
                      gapW8,
                      CustomTextFormField(
                        initialValue: oldConfig.host ?? '',
                        labelText: strings.host,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(host: value),
                        ),
                        validator: Validator.validateRequiredField,
                      ),
                    ],
                  ),
                  gapH10,
                  Row(
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.sendSshPublicKey,
                        labelText: strings.sendSshPublicKey,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(sendSshPublicKey: value),
                        ),
                        validator: Validator.validateRequiredField,
                      ),
                      gapW8,
                      Row(
                        children: [
                          Text(strings.rsa),
                          gapW8,
                          Switch(
                              value: newConfig.rsa ?? oldConfig.rsa,
                              onChanged: (newValue) {
                                setState(() {
                                  newConfig = SSHNPPartialParams.merge(
                                    newConfig,
                                    SSHNPPartialParams(rsa: newValue),
                                  );
                                });
                              }),
                        ],
                      ),
                    ],
                  ),
                  gapH10,
                  Row(
                    children: [
                      CustomTextFormField(
                          initialValue: oldConfig.remoteUsername ?? '',
                          labelText: strings.remoteUserName,
                          onChanged: (value) {
                            newConfig = SSHNPPartialParams.merge(
                              newConfig,
                              SSHNPPartialParams(remoteUsername: value),
                            );
                          }),
                      gapW8,
                      CustomTextFormField(
                        initialValue: oldConfig.port.toString(),
                        labelText: strings.port,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(port: int.tryParse(value)),
                        ),
                        validator: Validator.validateRequiredField,
                      ),
                    ],
                  ),
                  gapH10,
                  Row(
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.localPort.toString(),
                        labelText: strings.localPort,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(localPort: int.tryParse(value)),
                        ),
                      ),
                      gapW8,
                      CustomTextFormField(
                        initialValue: oldConfig.localSshdPort.toString(),
                        labelText: strings.localSshdPort,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(localSshdPort: int.tryParse(value)),
                        ),
                      ),
                    ],
                  ),
                  gapH10,
                  CustomTextFormField(
                    initialValue: oldConfig.localSshOptions.join(','),
                    hintText: strings.localSshOptionsHint,
                    labelText: strings.localSshOptions,
                    width: 192 * 2 + 10,
                    onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                      newConfig,
                      SSHNPPartialParams(localSshOptions: value.split(',')),
                    ),
                  ),
                  gapH10,
                  Row(
                    children: [
                      CustomTextFormField(
                        initialValue: oldConfig.atKeysFilePath,
                        labelText: strings.atKeysFilePath,
                        onChanged: (value) => newConfig = SSHNPPartialParams.merge(
                          newConfig,
                          SSHNPPartialParams(atKeysFilePath: value),
                        ),
                      ),
                      gapW8,
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
                  Row(
                    children: [
                      Text(strings.verbose),
                      gapW8,
                      Switch(
                          value: newConfig.verbose ?? oldConfig.verbose,
                          onChanged: (newValue) {
                            setState(() {
                              newConfig = SSHNPPartialParams.merge(
                                newConfig,
                                SSHNPPartialParams(verbose: newValue),
                              );
                            });
                          }),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => onSubmit(oldConfig, newConfig),
                        child: Text(strings.submit),
                      ),
                      gapW8,
                      TextButton(
                        onPressed: () {
                          ref.read(navRouteController.notifier).goTo(AppRoute.home);
                          context.pushReplacementNamed(AppRoute.home.name);
                        },
                        child: Text(strings.cancel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }
}
