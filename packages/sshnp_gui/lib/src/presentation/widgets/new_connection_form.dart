import 'dart:developer';

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
  late String? clientAtSign;
  late String? sshnpdAtSign;
  late String? host;

  /// Optional Arguments
  late String device;
  late int port;
  late int localPort;
  late String sendSshPublicKey;
  late List<String> localSshOptions;
  late bool verbose;
  late bool rsa;
  late String? remoteUsername;
  late String? atKeysFilePath;
  late String rootDomain;
  late bool listDevices;
  late bool legacyDaemon;
  @override
  void initState() {
    super.initState();

    final oldConfig = ref.read(sshnpParamsProvider);
    log(oldConfig.port.toString());
    clientAtSign = oldConfig.clientAtSign;
    sshnpdAtSign = oldConfig.sshnpdAtSign;
    host = oldConfig.host;

    /// Optional Arguments
    device = oldConfig.device;
    port = oldConfig.port;
    localPort = oldConfig.localPort;
    sendSshPublicKey = oldConfig.sendSshPublicKey;
    localSshOptions = oldConfig.localSshOptions;
    verbose = oldConfig.verbose;
    rsa = oldConfig.rsa;
    remoteUsername = oldConfig.remoteUsername;
    atKeysFilePath = oldConfig.atKeysFilePath;
    rootDomain = oldConfig.rootDomain;
    listDevices = oldConfig.listDevices;
    legacyDaemon = oldConfig.legacyDaemon;
  }

  void createNewConnection() async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();

      final sshnpParams = SSHNPParams(
          clientAtSign: clientAtSign,
          sshnpdAtSign: sshnpdAtSign,
          host: host,
          device: device,
          port: port,
          localPort: localPort,
          sendSshPublicKey: sendSshPublicKey,
          localSshOptions: localSshOptions,
          verbose: verbose,
          rsa: rsa,
          remoteUsername: remoteUsername,
          atKeysFilePath: atKeysFilePath,
          rootDomain: rootDomain,
          listDevices: listDevices,
          legacyDaemon: legacyDaemon);
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
      // Reset value to default value.
      ref
          .read(sshnpParamsProvider.notifier)
          .update((state) => SSHNPParams(clientAtSign: '', sshnpdAtSign: '', host: '', legacyDaemon: true));
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
                initialValue: clientAtSign,
                labelText: strings.clientAtsign,
                onSaved: (value) => clientAtSign = value,
                validator: Validator.validateAtsignField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: host,
                labelText: strings.host,
                onSaved: (value) => host = value,
                validator: Validator.validateRequiredField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: port.toString(),
                labelText: strings.port,
                onSaved: (value) => port = int.parse(value!),
                validator: Validator.validateRequiredField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: sendSshPublicKey,
                labelText: strings.sendSshPublicKey,
                onSaved: (value) => sendSshPublicKey = value!,
              ),
              gapH10,
              Row(
                children: [
                  Text(strings.verbose),
                  gapW12,
                  Switch(
                      value: verbose,
                      onChanged: (newValue) {
                        setState(() {
                          verbose = newValue;
                        });
                      }),
                ],
              ),
              gapH10,
              CustomTextFormField(
                initialValue: remoteUsername,
                labelText: strings.remoteUserName,
                onSaved: (value) => remoteUsername = value!,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: rootDomain,
                labelText: strings.rootDomain,
                onSaved: (value) => rootDomain = value!,
              ),
              gapH20,
              ElevatedButton(
                onPressed: createNewConnection,
                child: Text(strings.add),
              ),
            ]),
            gapW12,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomTextFormField(
                initialValue: sshnpdAtSign,
                labelText: strings.sshnpdAtSign,
                onSaved: (value) => sshnpdAtSign = value,
                validator: Validator.validateAtsignField,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: device,
                labelText: strings.device,
                onSaved: (value) => device = value!,
              ),
              gapH10,
              CustomTextFormField(
                initialValue: localPort.toString(),
                labelText: strings.localPort,
                onSaved: (value) => localPort = int.parse(value!),
              ),
              gapH10,
              CustomTextFormField(
                initialValue: localSshOptions.join(','),
                labelText: strings.localSshOptions,
                onSaved: (value) => localSshOptions = value!.split(','),
              ),
              gapH10,
              Row(
                children: [
                  Text(strings.rsa),
                  gapW12,
                  Switch(
                      value: rsa,
                      onChanged: (newValue) {
                        setState(() {
                          rsa = newValue;
                        });
                      }),
                ],
              ),
              gapH10,
              CustomTextFormField(
                initialValue: atKeysFilePath,
                labelText: strings.atKeysFilePath,
                onSaved: (value) => atKeysFilePath = value,
              ),
              gapH10,
              Row(
                children: [
                  Text(strings.listDevices),
                  gapW12,
                  Switch(
                      value: listDevices,
                      onChanged: (newValue) {
                        setState(() {
                          listDevices = newValue;
                        });
                      }),
                ],
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
