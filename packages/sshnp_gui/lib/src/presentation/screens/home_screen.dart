import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshrv/sshrv.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';
import 'package:sshnp_gui/src/presentation/widgets/sshnp_result_alert_dialog.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

import '../../controllers/home_screen_controller.dart';
import '../../utils/app_router.dart';
import '../../utils/sizes.dart';
import '../widgets/app_navigation_rail.dart';
import '../widgets/custom_table_cell.dart';
import '../widgets/delete_alert_dialog.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(homeScreenControllerProvider.notifier).getConfigFiles();
    });
    super.initState();
  }

  Future<void> ssh(SSHNPParams sshnpParams) async {
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final sshnp = await SSHNP.fromParams(
        sshnpParams,
        atClient: AtClientManager.getInstance().atClient,
        sshrvGenerator: SSHRV.pureDart,
      );

      await sshnp.init();
      final sshnpResult = await sshnp.run();

      if (mounted) {
        // pop to remove circular progress indicator
        context.pop();
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => SSHNPResultAlertDialog(
            result: sshnpResult.toString(),
            title: 'Success',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.pop();
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => SSHNPResultAlertDialog(
            result: e.toString(),
            title: 'Failed',
          ),
        );
      }
    }
  }

  void updateConfigFile(SSHNPParams sshnpParams) {
    ref.read(sshnpParamsProvider.notifier).update((state) => sshnpParams);
    // change value to 1 to update navigation rail selcted icon.
    ref.read(currentNavIndexProvider.notifier).update((state) => AppRoute.newConnection.index - 1);
    // Change value to update to trigger the update functionality on the new connection form.
    ref.read(configFileWriteStateProvider.notifier).update((state) => ConfigFileWriteState.update);
    context.replaceNamed(
      AppRoute.newConnection.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below

    final strings = AppLocalizations.of(context)!;
    final state = ref.watch(homeScreenControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SvgPicture.asset(
                    'assets/images/noports_light.svg',
                  ),
                  gapH24,
                  Text(strings.availableConnections),
                  state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : state.value!.isNotEmpty
                          ? Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Table(
                                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                  columnWidths: const {
                                    0: IntrinsicColumnWidth(),
                                    1: IntrinsicColumnWidth(),
                                    2: IntrinsicColumnWidth(),
                                    3: IntrinsicColumnWidth(),
                                    4: IntrinsicColumnWidth(),
                                    5: IntrinsicColumnWidth(),
                                    6: FixedColumnWidth(150),
                                  },
                                  children: [
                                    TableRow(
                                      decoration:
                                          const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white))),
                                      children: <Widget>[
                                        CustomTableCell.text(text: strings.actions),
                                        CustomTableCell.text(text: strings.clientAtsign), // todo change this to strings.profileName
                                        CustomTableCell.text(text: strings.sshnpdAtSign),
                                        CustomTableCell.text(text: strings.device),
                                        CustomTableCell.text(text: strings.port),
                                        CustomTableCell.text(text: strings.localPort),
                                        CustomTableCell.text(text: strings.localSshOptions),
                                      ],
                                    ),
                                    ...state.value!
                                        .map(
                                          (e) => TableRow(
                                            children: <Widget>[
                                              CustomTableCell(
                                                  child: Row(
                                                children: [
                                                  IconButton(
                                                    onPressed: () async {
                                                      await ssh(e);
                                                    },
                                                    icon: const Icon(Icons.connect_without_contact_outlined),
                                                  ),
                                                  IconButton(
                                                    onPressed: () {
                                                      // get the index of the config file so it can be updated
                                                      ref
                                                          .read(sshnpParamsUpdateIndexProvider.notifier)
                                                          .update((value) => state.value!.indexOf(e));
                                                      updateConfigFile(e);
                                                    },
                                                    icon: const Icon(Icons.edit),
                                                  ),
                                                  IconButton(
                                                    onPressed: () async {
                                                      showDialog<void>(
                                                        context: context,
                                                        barrierDismissible: false,
                                                        builder: (BuildContext context) =>
                                                            DeleteAlertDialog(index: state.value!.indexOf(e)),
                                                      );
                                                    },
                                                    icon: const Icon(Icons.delete_forever),
                                                  ),
                                                ],
                                              )),
                                              CustomTableCell.text(text: e.profileName ?? ''),
                                              CustomTableCell.text(text: e.sshnpdAtSign ?? ''),
                                              CustomTableCell.text(text: e.device),
                                              CustomTableCell.text(text: e.port.toString()),
                                              CustomTableCell.text(text: e.localPort.toString()),
                                              CustomTableCell.text(text: e.localSshOptions.join(',')),
                                              // CustomTableCell(
                                              //     child: Row(
                                              //   children: [
                                              //     TextButton.icon(
                                              //         onPressed: () {
                                              //           context.pushNamed(StudentRoute.details.name, params: {'id': e.id});
                                              //         },
                                              //         icon: const Icon(Icons.visibility_outlined),
                                              //         label: Text(strings.view)),
                                              //   ],
                                              // ))
                                            ],
                                          ),
                                        )
                                        .toList()
                                  ],
                                ),
                              ),
                            )
                          : const Text('No SSHNP Configurations Found')
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
