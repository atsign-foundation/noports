import 'dart:developer';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_flutter/src/controllers/form_controllers.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_flutter/src/controllers/private_key_manager_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_flutter/src/presentation/widgets/ssh_key_management/file_picker_field.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/form_validator.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../../application/private_key_manager.dart';
import '../../../controllers/file_picker_controller.dart';

class SSHKeyManagementFormDialog extends ConsumerStatefulWidget {
  const SSHKeyManagementFormDialog({this.identifier, super.key});

  final String? identifier;

  @override
  ConsumerState<SSHKeyManagementFormDialog> createState() => _SSHKeyManagementFormState();
}

class _SSHKeyManagementFormState extends ConsumerState<SSHKeyManagementFormDialog> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  late String nickname;
  String? passPhrase;
  late String content;
  String privateKeyFileName = '';
  XFile? file;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> getPrivateKey() async {
    try {
      file = await openFile(acceptedTypeGroups: <XTypeGroup>[dotPrivateTypeGroup]);
      if (file == null) return;
      content = await file!.readAsString();
      setState(() {
        privateKeyFileName = file!.name;
      });
      setState(() {});
    } catch (e) {
      log(e.toString());
    }
  }

  void onSubmit(BuildContext context) async {
    final fileDetails = ref.read(filePickerController.notifier);
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save();

      final privateKeyManager = PrivateKeyManager(
        nickname: nickname,
        content: await fileDetails.content,
        privateKeyFileName: fileDetails.fileName,
        passPhrase: passPhrase,
        directory: fileDetails.directory,
      );
      fileDetails.clearFileDetails();
      final controller = ref.read(privateKeyManagerFamilyController(nickname).notifier);

      await controller.savePrivateKeyManager(privateKeyManager: privateKeyManager);

      if (mounted) {
        ref.read(navigationRailController.notifier).setRoute(AppRoute.home);
        context.pop(nickname);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    final asyncOldConfig = ref.watch(privateKeyManagerFamilyController(widget.identifier ?? ''));

    return asyncOldConfig.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (oldPrivateKeyManager) {
          nickname = oldPrivateKeyManager.nickname;
          passPhrase = oldPrivateKeyManager.passPhrase;
          content = oldPrivateKeyManager.content;
          privateKeyFileName = oldPrivateKeyManager.privateKeyFileName;

          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.p21),
              child: SingleChildScrollView(
                child: Form(
                  key: _formkey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      gapH20,
                      Text(strings.sshKeyManagement('no'), style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        strings.privateKeyManagementDescription,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white),
                      ),
                      gapH16,
                      Text(strings.newSshKeyCreation),
                      gapH4,
                      FilePickerField(
                        onTap: () async {
                          await getPrivateKey();
                        },
                        initialValue: privateKeyFileName,
                        validator: FormValidator.validateRequiredField,
                      ),
                      gapH10,
                      CustomTextFormField(
                        initialValue: nickname,
                        labelText: strings.privateKeyNickname,
                        toolTip: strings.privateKeyNicknameToolTip,
                        onSaved: (value) {
                          nickname = value!;
                          ref.read(formProfileNameController.notifier).state = value;
                          log(ref.read(formProfileNameController));
                        },
                        validator: FormValidator.validatePrivateKeyField,
                      ),
                      gapH10,
                      CustomTextFormField(
                        labelText: strings.privateKeyPassphrase,
                        initialValue: passPhrase,
                        toolTip: strings.privatekeyPassPhraseTooltip,
                        isPasswordField: true,
                        onSaved: (value) {
                          if (value == '' || value == null) {
                            passPhrase = null;
                          } else {
                            passPhrase = value;
                          }
                          log('passphrase is $value');
                        },
                      ),
                      gapH36,
                      SizedBox(
                        width: kFieldDefaultWidth + Sizes.p233,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton(
                              onPressed: () {
                                ref.read(navigationRailController.notifier).setRoute(AppRoute.home);
                                context.pop();
                              },
                              child: Text(strings.cancel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(decoration: TextDecoration.underline)),
                            ),
                            gapW8,
                            ElevatedButton(
                              onPressed: () => onSubmit(context),
                              child: Text(strings.addKey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}
