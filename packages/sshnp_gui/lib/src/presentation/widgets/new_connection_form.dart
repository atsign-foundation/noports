import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/home_screen_controller.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';
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
  late SSHNPPartialParams oldConfig;
  @override
  void initState() {
    super.initState();
    oldConfig = ref.read(sshnpPartialParamsProvider);
  }

  void createNewConnection() async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();
      oldConfig.clientAtSign ??= AtClientManager.getInstance().atClient.getCurrentAtSign();
      // reset the partial params to empty so that the next time the user clicks on new connection the form is empty.
      ref.read(sshnpPartialParamsProvider.notifier).update((state) => SSHNPPartialParams.empty());

      final sshnpParams = SSHNPParams.fromPartial(oldConfig);
      switch (ref.read(configFileWriteStateProvider)) {
        case ConfigFileWriteState.create:
          await ref.read(homeScreenControllerProvider.notifier).createConfigFile(sshnpParams);
          break;
        case ConfigFileWriteState.update:
          log('update_worked');
          await ref.read(homeScreenControllerProvider.notifier).updateConfigFile(sshnpParams: sshnpParams);
          // set value to default create so trigger the create functionality on
          ref.read(configFileWriteStateProvider.notifier).update((state) => ConfigFileWriteState.create);
          break;
      }
      if (context.mounted) {
        ref.read(currentNavIndexProvider.notifier).update((state) => AppRoute.home.index - 1);
        context.pushReplacementNamed(AppRoute.home.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Form(
        key: _formkey,
        child: Row(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomTextFormField(
                initialValue: oldConfig.profileName,
                labelText: strings.profileName,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(profileName: value!)),
                validator: Validator.validateRequiredField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.host,
                labelText: strings.host,
                onSaved: (value) => oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(host: value!)),
                validator: Validator.validateRequiredField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.port.toString(),
                labelText: strings.port,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(port: int.parse(value!))),
                validator: Validator.validateRequiredField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.sendSshPublicKey,
                labelText: strings.sendSshPublicKey,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(sendSshPublicKey: value!)),
                validator: Validator.validateRequiredField,
              ),
              gapH10,
              Row(
                children: [
                  Text(strings.verbose),
                  gapW8,
                  Switch(
                      value: oldConfig.verbose ?? false,
                      onChanged: (newValue) {
                        setState(() {
                          oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(verbose: newValue));
                        });
                      }),
                ],
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.remoteUsername,
                labelText: strings.remoteUserName,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(remoteUsername: value!)),
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.rootDomain,
                labelText: strings.rootDomain,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(rootDomain: value!)),
              ),
              gapH20,
              ElevatedButton(
                onPressed: createNewConnection,
                child: Text(strings.submit),
              ),
            ]),
            gapW12,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomTextFormField(
                initialValue: oldConfig.sshnpdAtSign,
                labelText: strings.sshnpdAtSign,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(sshnpdAtSign: value!)),
                validator: Validator.validateAtsignField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.device,
                labelText: strings.device,
                onSaved: (value) => oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(device: value!)),
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.localPort.toString(),
                labelText: strings.localPort,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(localPort: int.parse(value!))),
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.localSshOptions.join(','),
                hintText: strings.localSshOptionsHint,
                labelText: strings.localSshOptions,
                onSaved: (value) => oldConfig =
                    SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(localSshOptions: value!.split(','))),
              ),
              gapH10,
              Row(
                children: [
                  Text(strings.rsa),
                  gapW8,
                  Switch(
                      value: oldConfig.rsa ?? false,
                      onChanged: (newValue) {
                        setState(() {
                          oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(rsa: newValue));
                        });
                      }),
                ],
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.atKeysFilePath,
                labelText: strings.atKeysFilePath,
                onSaved: (value) =>
                    oldConfig = SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(atKeysFilePath: value!)),
              ),
              gapH10,
              CustomTextFormField(
                initialValue: oldConfig.localSshdPort.toString(),
                labelText: strings.localSshdPort,
                onSaved: (value) => oldConfig =
                    SSHNPPartialParams.merge(oldConfig, SSHNPPartialParams(localSshdPort: int.parse(value!))),
              ),
              gapH20,
              TextButton(
                  onPressed: () {
                    ref.read(currentNavIndexProvider.notifier).update((state) => AppRoute.home.index - 1);
                    context.pushReplacementNamed(AppRoute.home.name);
                  },
                  child: Text(strings.cancel))
            ]),
          ],
        ),
      ),
    );
  }
}
