import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/custom_app_bar.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';
import 'package:xterm/xterm.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreenMobileView extends ConsumerStatefulWidget {
  const TerminalScreenMobileView({Key? key}) : super(key: key);

  @override
  ConsumerState<TerminalScreenMobileView> createState() => _TerminalScreenMobileState();
}

class _TerminalScreenMobileState extends ConsumerState<TerminalScreenMobileView> with TickerProviderStateMixin {
  final terminalController = TerminalController();
  late final Pty pty;
  @override
  void initState() {
    super.initState();
    final sessionId = ref.read(terminalSessionController);

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

  void closeSession(String sessionId) {
    // Remove the session from the list of sessions
    final controller = ref.read(terminalSessionFamilyController(sessionId).notifier);
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final terminalList = ref.watch(terminalSessionListController);
    final currentSessionId = ref.watch(terminalSessionController);
    final int currentIndex = (terminalList.isEmpty) ? 0 : terminalList.indexOf(currentSessionId);
    final tabController = TabController(initialIndex: currentIndex, length: terminalList.length, vsync: this);

    return Scaffold(
      appBar: CustomAppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.terminal, style: Theme.of(context).textTheme.headlineLarge),
        Text.rich(
          TextSpan(
              text: terminalList.isNotEmpty ? terminalList.length.toString() : '0 ',
              style: Theme.of(context).textTheme.bodySmall!,
              children: [
                TextSpan(text: strings.terminalDescription),
              ]),
        ),
      ])),
      body: Padding(
        padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21, right: Sizes.p36),
        child: terminalList.isEmpty
            ? Center(
                child: Text(
                  strings.noTerminalSessionsHelp,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                children: terminalList.map((String sessionId) {
                  final displayName = ref.read(terminalSessionFamilyController(sessionId).notifier).displayName;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text(displayName),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => closeSession(sessionId),
                          )
                        ],
                      ),
                      TerminalView(
                        key: Key('terminal-view-$sessionId'),
                        ref.watch(terminalSessionFamilyController(sessionId)).terminal,
                        controller: terminalController,
                        autofocus: true,
                        autoResize: true,
                      )
                    ],
                  );
                }).toList(),
              ),
      ),
    );
  }
}
