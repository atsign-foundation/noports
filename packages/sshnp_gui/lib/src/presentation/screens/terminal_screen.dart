import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnp_gui/src/controllers/nav_route_controller.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/utils/sizes.dart';
import 'package:xterm/xterm.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final terminalController = TerminalController();
  late final Pty pty;

  @override
  void initState() {
    super.initState();
    final sessionId = ref.read(terminalSessionController);
    print('sessionId in initState: $sessionId');

    final sessionController = ref.read(terminalSessionFamilyController(sessionId).notifier);
    WidgetsBinding.instance.endOfFrame.then((value) {
      sessionController.startProcess();
    });
  }

  @override
  void dispose() {
    terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below
    final sessionId = ref.watch(terminalSessionController);
    print('sessionId in build: $sessionId');
    final terminalSession = ref.watch(terminalSessionFamilyController(sessionId));
    return Scaffold(
      body: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21, right: Sizes.p36),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SvgPicture.asset(
                    'assets/images/noports_light.svg',
                  ),
                  gapH24,
                  Expanded(
                    child: TerminalView(
                      terminalSession.terminal,
                      controller: terminalController,
                      autofocus: true,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
