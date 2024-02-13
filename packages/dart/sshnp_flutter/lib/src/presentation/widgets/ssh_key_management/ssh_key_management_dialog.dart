import 'dart:developer';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/controllers/private_key_manager_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/ssh_key_management/ssh_key_pair_bar.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import 'ssh_key_management_form_dialog.dart';

// * Once the onboarding process is completed you will be taken to this screen
class SshKeyManagementDialog extends ConsumerStatefulWidget {
  const SshKeyManagementDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<SshKeyManagementDialog> createState() =>
      _SshKeyManagementScreenState();
}

class _SshKeyManagementScreenState
    extends ConsumerState<SshKeyManagementDialog> {
  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below

    final strings = AppLocalizations.of(context)!;
    final privateKeyManager = ref.watch(atPrivateKeyManagerListController);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.only(
          left: Sizes.p36,
          top: Sizes.p21,
          right: Sizes.p36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.privateKeyManagement,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              strings.privateKeyManagementDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            gapH20,
            privateKeyManager.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, s) {
                return Text(e.toString());
              },
              data: (privateKeys) {
                if (privateKeys.isEmpty) {
                  return Text(strings.privateKeyNotFound);
                }
                final sortedPrivateKeys = privateKeys.toList();
                sortedPrivateKeys.sort();
                log(sortedPrivateKeys.toString());
                return Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(text: strings.yourKeys, children: [
                          TextSpan(
                            text: ' ${sortedPrivateKeys.length}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(color: kPrimaryColor),
                          ),
                        ]),
                      ),
                      SizedBox(
                        width: 411,
                        height: 122,
                        child: Card(
                          color: kSSHKeyManagementCardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GridView.builder(
                              itemCount: sortedPrivateKeys.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 190 / 60,
                              ),
                              itemBuilder: (context, index) {
                                return SshKeyPairBar(sortedPrivateKeys[index]);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            gapH20,
            GestureDetector(
              onTap: () async {
                await showDialog(
                    context: context,
                    builder: ((context) => const SSHKeyManagementFormDialog()));
              },
              child: DottedBorder(
                dashPattern: const [10, 10],
                color: kPrimaryColor,
                radius: const Radius.circular(Sizes.p5),
                padding: const EdgeInsets.all(Sizes.p12),
                child: SizedBox(
                  width: 380,
                  child: Center(
                    child: Text(
                      strings.uploadNewKey,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(color: kPrimaryColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
