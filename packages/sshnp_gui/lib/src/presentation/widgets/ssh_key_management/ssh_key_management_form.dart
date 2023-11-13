import 'dart:developer';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/form_controllers.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_gui/src/controllers/ssh_key_pair_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_gui/src/presentation/widgets/ssh_key_management/file_picker_field.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/form_validator.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

import '../../../application/at_ssh_key_pair_manager.dart';
import '../../../controllers/file_picker_controller.dart';
import '../profile_form/profile_form_card.dart';

class SSHKeyManagementForm extends ConsumerStatefulWidget {
  const SSHKeyManagementForm({super.key});

  @override
  ConsumerState<SSHKeyManagementForm> createState() => _SSHKeyManagementFormState();
}

class _SSHKeyManagementFormState extends ConsumerState<SSHKeyManagementForm> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late CurrentConfigState currentProfile;
  late String nickname;
  // TODO: Handle olde passPhrase and content info and clean up this form
  String? passPhrase;
  late String content;
  String privateKeyFileName = '';
  XFile? file;
  // late TextEditingController filePickerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(formProfileNameController.notifier).state = currentProfile.profileName;
    });
  }

  @override
  void dispose() {
    // filePickerController.dispose();
    super.dispose();
  }

  Future<void> getPrivateKey() async {
    try {
      file = await openFile(acceptedTypeGroups: <XTypeGroup>[dotPrivateTypeGroup]);
      if (file == null) return;
      content = await file!.readAsString();
      setState(() {
        privateKeyFileName = file!.name;

        // log(filePickerController.text);
      });
      setState(() {});
    } catch (e) {
      log(e.toString());
    }
  }

  void onSubmit() async {
    final fileDetails = ref.read(filePickerController.notifier);
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();

      final atSshKeyPairManager = AtSshKeyPairManager(
          nickname: nickname,
          content: await fileDetails.content,
          privateKeyFileName: fileDetails.fileName,
          passPhrase: passPhrase);
      fileDetails.clearFileDetails();
      final controller = ref.read(atSSHKeyPairManagerFamilyController(nickname).notifier);
      await controller.deleteAtSSHKeyPairManager(identifier: 'test');

      await controller.saveAtSshKeyPairManager(atSshKeyPairManager: atSshKeyPairManager);

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

    final asyncOldConfig = ref.watch(atSSHKeyPairManagerFamilyController(currentProfile.profileName));

    return asyncOldConfig.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (oldAtSshKeyPairManager) {
          nickname = oldAtSshKeyPairManager.nickname;
          passPhrase = oldAtSshKeyPairManager.passPhrase;
          content = oldAtSshKeyPairManager.content;
          privateKeyFileName = oldAtSshKeyPairManager.privateKeyFileName;

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
                      initialValue: nickname,
                      labelText: strings.nickName,
                      onSaved: (value) {
                        nickname = value!;
                        ref.read(formProfileNameController.notifier).state = value;
                        log(ref.read(formProfileNameController));
                      },
                      validator: FormValidator.validateProfileNameField,
                    ),
                    gapH10,
                    FilePickerField(
                      onTap: () async {
                        await getPrivateKey();
                      },
                      initialValue: privateKeyFileName,
                      validator: FormValidator.validateRequiredField,
                    ),
                    gapH10,
                    CustomTextFormField(
                      labelText: 'SSH Key Password',
                      initialValue: passPhrase,
                      isPasswordField: true,
                      onSaved: (value) => passPhrase = value,
                    ),
                    gapH10,
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
                          onPressed: () => onSubmit(),
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
