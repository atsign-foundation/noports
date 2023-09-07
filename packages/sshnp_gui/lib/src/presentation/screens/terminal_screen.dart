import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';
import 'package:xterm/xterm.dart';

import '../../utils/sizes.dart';
import '../widgets/navigation/app_navigation_rail.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  var terminal = Terminal();
  final terminalController = TerminalController();
  late final Pty pty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((value) {
      if (mounted) _startPty();
    });
  }

  void _startPty({String? command, List<String>? args}) {
    pty = Pty.start(
      command ?? Platform.environment['SHELL'] ?? 'bash',
      arguments: args ?? [],
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );

    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen(terminal.write);

    pty.exitCode.then(
      (code) => terminal.write('the process exited with code $code'),
    );

    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };

    // write ssh result command to terminal
    pty.write(const Utf8Encoder().convert(ref.watch(terminalSSHCommandProvider)));
    // reset provider
    ref.watch(terminalSSHCommandProvider.notifier).update((state) => '');
  }

  @override
  void dispose() {
    terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below

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
                      terminal,
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
