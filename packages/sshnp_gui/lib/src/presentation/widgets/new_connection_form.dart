import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/sshnp_params.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/validator.dart';

import '../../utils/sizes.dart';
import 'custom_text_form_field.dart';

class NewConnectionForm extends StatefulWidget {
  const NewConnectionForm({super.key});

  @override
  State<NewConnectionForm> createState() => _NewConnectionFormState();
}

class _NewConnectionFormState extends State<NewConnectionForm> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  String? clientAtSign;
  String? sshnpdAtSign;
  String? host;

  /// Optional Arguments
  String device = 'default';
  String port = '22';
  String localPort = '0';
  String sendSshPublicKey = 'false';
  List<String> localSshOptions = [];
  bool verbose = false;
  bool rsa = false;
  String? remoteUsername;
  String? atKeysFilePath;
  String rootDomain = 'root.atsign.org';
  bool listDevices = false;
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
          listDevices: listDevices);
      final homeDir = getHomeDirectory()!;
      log(homeDir);
      final configDir = getDefaultSshnpConfigDirectory(homeDir);
      log(configDir);
      await Directory(configDir).create(recursive: true);
      //.env
      sshnpParams.toFile('$configDir/$clientAtSign-$sshnpdAtSign-$device.env', overwrite: true);

      if (context.mounted) {
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
                initialValue: port,
                labelText: strings.port,
                onSaved: (value) => port = value!,
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
                initialValue: localPort,
                labelText: strings.localPort,
                onSaved: (value) => localPort = value!,
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
