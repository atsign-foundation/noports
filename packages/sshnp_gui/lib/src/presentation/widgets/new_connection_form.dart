import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';
import 'package:sshnp_gui/src/controllers/sshnp_config_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/enum.dart';
import 'package:sshnp_gui/src/utils/validator.dart';

import '../../utils/sizes.dart';
import 'custom_text_form_field.dart';

class NewConnectionForm extends ConsumerStatefulWidget {
  const NewConnectionForm({super.key});

  @override
  ConsumerState<NewConnectionForm> createState() => _NewConnectionFormState();
}

class _NewConnectionFormState extends ConsumerState<NewConnectionForm> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentSSHNPParamsModel currentProfile;
  @override
  void initState() {
    currentProfile = ref.read(currentParamsController);
    super.initState();
  }

  void onSubmit(config) async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      bool overwrite =
          currentProfile.configFileWriteState == ConfigFileWriteState.update;
      await config.toFile(overwrite: overwrite);
      if (context.mounted) {
        ref
            .read(currentNavIndexProvider.notifier)
            .update((state) => AppRoute.home.index - 1);
        context.pushReplacementNamed(AppRoute.home.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final oldConfig =
        ref.read(paramsFamilyController(currentProfile.profileName));
    return oldConfig.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (config) => SingleChildScrollView(
        child: Form(
          key: _formkey,
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CustomTextFormField(
                  initialValue: config.profileName,
                  labelText: strings.profileName,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(profileName: value!)),
                  validator: Validator.validateRequiredField,
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.host,
                  labelText: strings.host,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(host: value!)),
                  validator: Validator.validateRequiredField,
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.port.toString(),
                  labelText: strings.port,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(port: int.parse(value!))),
                  validator: Validator.validateRequiredField,
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.sendSshPublicKey,
                  labelText: strings.sendSshPublicKey,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(sendSshPublicKey: value!)),
                  validator: Validator.validateRequiredField,
                ),
                gapH10,
                Row(
                  children: [
                    Text(strings.verbose),
                    gapW8,
                    Switch(
                        value: config.verbose,
                        onChanged: (newValue) {
                          setState(() {
                            config = SSHNPParams.merge(
                                config, SSHNPPartialParams(verbose: newValue));
                          });
                        }),
                  ],
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.remoteUsername,
                  labelText: strings.remoteUserName,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(remoteUsername: value!)),
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.rootDomain,
                  labelText: strings.rootDomain,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(rootDomain: value!)),
                ),
                gapH20,
                ElevatedButton(
                  onPressed: () => onSubmit(config),
                  child: Text(strings.submit),
                ),
              ]),
              gapW12,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CustomTextFormField(
                  initialValue: config.sshnpdAtSign,
                  labelText: strings.sshnpdAtSign,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(sshnpdAtSign: value!)),
                  validator: Validator.validateAtsignField,
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.device,
                  labelText: strings.device,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(device: value!)),
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.localPort.toString(),
                  labelText: strings.localPort,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(localPort: int.parse(value!))),
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.localSshOptions.join(','),
                  hintText: strings.localSshOptionsHint,
                  labelText: strings.localSshOptions,
                  onSaved: (value) => config = SSHNPParams.merge(config,
                      SSHNPPartialParams(localSshOptions: value!.split(','))),
                ),
                gapH10,
                Row(
                  children: [
                    Text(strings.rsa),
                    gapW8,
                    Switch(
                        value: config.rsa,
                        onChanged: (newValue) {
                          setState(() {
                            config = SSHNPParams.merge(
                                config, SSHNPPartialParams(rsa: newValue));
                          });
                        }),
                  ],
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.atKeysFilePath,
                  labelText: strings.atKeysFilePath,
                  onSaved: (value) => config = SSHNPParams.merge(
                      config, SSHNPPartialParams(atKeysFilePath: value!)),
                ),
                gapH10,
                CustomTextFormField(
                  initialValue: config.localSshdPort.toString(),
                  labelText: strings.localSshdPort,
                  onSaved: (value) => config = SSHNPParams.merge(config,
                      SSHNPPartialParams(localSshdPort: int.parse(value!))),
                ),
                gapH20,
                TextButton(
                    onPressed: () {
                      ref
                          .read(currentNavIndexProvider.notifier)
                          .update((state) => AppRoute.home.index - 1);
                      context.pushReplacementNamed(AppRoute.home.name);
                    },
                    child: Text(strings.cancel))
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
