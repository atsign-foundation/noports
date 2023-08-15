import 'dart:developer';
import 'dart:io';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/sshnp_impl.dart';
import 'package:sshnoports/sshnp/sshnp_params.dart';

import '../../utils/sizes.dart';
import '../widgets/app_navigation_rail.dart';
import '../widgets/custom_table_cell.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SSHNP> sshnpList = [];
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final sshnpParms = await SSHNPParams.getConfigFilesFromDirectory();
        sshnpList = await Future.wait(sshnpParms
            .map((e) => SSHNPImpl.fromParams(
                  e,
                  atClient: AtClientManager.getInstance().atClient,
                ))
            .toList());
        setState(() {});
      } on PathNotFoundException {
        log('Path Not Found');
      }
    });

    super.initState();
  }

  Future<void> ssh(SSHNP sshnp) async {
    await sshnp.init();
    await sshnp.run();
  }

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below
    AtClientManager atClientManager = AtClientManager.getInstance();
    final strings = AppLocalizations.of(context)!;

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
                  sshnpList.isNotEmpty
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
                                6: IntrinsicColumnWidth(),
                                7: FixedColumnWidth(200),
                                8: FixedColumnWidth(150),
                                9: FixedColumnWidth(100),
                                10: FixedColumnWidth(150),
                              },
                              children: [
                                TableRow(
                                  decoration:
                                      const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white))),
                                  children: <Widget>[
                                    CustomTableCell.text(text: strings.actions),
                                    CustomTableCell.text(text: strings.clientAtsign),
                                    CustomTableCell.text(text: strings.sshnpdAtSign),
                                    CustomTableCell.text(text: strings.device),
                                    CustomTableCell.text(text: strings.port),
                                    CustomTableCell.text(text: strings.localPort),
                                    CustomTableCell.text(text: strings.username),
                                    CustomTableCell.text(text: strings.homeDirectory),
                                    CustomTableCell.text(text: strings.sessionId),
                                    CustomTableCell.text(text: strings.sendSshPublicKey),
                                    CustomTableCell.text(text: strings.localSshOptions),
                                  ],
                                ),
                                ...sshnpList
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
                                                onPressed: () async {
                                                  // showDialog<void>(
                                                  //   context: context,
                                                  //   barrierDismissible: false,
                                                  //   builder: (BuildContext context) => DeleteAlertDialog(
                                                  //     atData: widget.atData,
                                                  //   ),
                                                  // );
                                                },
                                                icon: const Icon(Icons.delete_forever),
                                              ),
                                              IconButton(
                                                onPressed: () async {},
                                                icon: const Icon(Icons.edit),
                                              ),
                                            ],
                                          )),
                                          CustomTableCell.text(text: e.clientAtSign),
                                          CustomTableCell.text(text: e.sshnpdAtSign),
                                          CustomTableCell.text(text: e.device),
                                          CustomTableCell.text(text: e.port),
                                          CustomTableCell.text(text: e.localPort),
                                          CustomTableCell.text(text: e.username),
                                          CustomTableCell.text(text: e.homeDirectory),
                                          CustomTableCell.text(text: e.sessionId),
                                          CustomTableCell.text(text: e.sendSshPublicKey),
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
