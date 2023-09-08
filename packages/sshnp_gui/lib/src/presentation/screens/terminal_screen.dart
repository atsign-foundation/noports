import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> with TickerProviderStateMixin {
  final terminalController = TerminalController();
  late final Pty pty;

  @override
  void initState() {
    super.initState();
    final sessionId = ref.read(terminalSessionController);

    final sessionController = ref.read(terminalSessionFamilyController(sessionId).notifier);
    WidgetsBinding.instance.endOfFrame.then((value) {
      sessionController.startProcess(exitCallback: (int exitCode) {
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    terminalController.dispose();
    super.dispose();
  }

  void deleteTab(String sessionId) {
    final controller = ref.read(terminalSessionFamilyController(sessionId).notifier);
    final terminalList = ref.watch(terminalSessionListController);
    final currentSessionId = ref.read(terminalSessionController);
    final currentIndex = terminalList.indexOf(currentSessionId);

    // If the session we are deleting is the active session
    // we need to set a new active session
    if (currentSessionId == sessionId) {
      if (currentIndex > 0) {
        // set active terminal to the one immediately to the left
        ref.read(terminalSessionController.notifier).setSession(terminalList[currentIndex - 1]);
      } else if (terminalList.length > 1) {
        // set active terminal to the one immediately to the right
        ref.read(terminalSessionController.notifier).setSession(terminalList[currentIndex + 1]);
      } else {
        // no other sessions available, set active terminal to empty string
        ref.read(terminalSessionController.notifier).setSession('');
      }
    }

    controller.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final terminalList = ref.watch(terminalSessionListController);
    final currentSessionId = ref.watch(terminalSessionController);
    late final int currentIndex;
    if (terminalList.isEmpty) {
      currentIndex = 0;
    } else {
      currentIndex = terminalList.indexOf(currentSessionId);
    }
    final tabController = TabController(initialIndex: currentIndex, length: terminalList.length, vsync: this);

    return Scaffold(
      body: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21, right: Sizes.p36),
                child: DefaultTabController(
                  length: terminalList.length,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SvgPicture.asset(
                      'assets/images/noports_light.svg',
                    ),
                    gapH24,
                    if (terminalList.isEmpty) Text(strings.noTerminalSessions, textScaleFactor: 2),
                    if (terminalList.isEmpty) Text(strings.noTerminalSessionsHelp),
                    if (terminalList.isNotEmpty)
                      TabBar(
                        controller: tabController,
                        isScrollable: true,
                        onTap: (index) {
                          ref.read(terminalSessionController.notifier).setSession(terminalList[index]);
                        },
                        tabs: terminalList.map((String sessionId) {
                          final displayName = ref.read(terminalSessionFamilyController(sessionId).notifier).displayName;
                          return Tab(
                            // text: e,
                            key: Key('terminal-tab-$sessionId'),
                            child: Row(
                              children: [
                                Text(displayName),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => deleteTab(sessionId),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    if (terminalList.isNotEmpty) gapH24,
                    if (terminalList.isNotEmpty)
                      Expanded(
                        child: TabBarView(
                          controller: tabController,
                          children: terminalList.map((String sessionId) {
                            return TerminalView(
                              key: Key('terminal-view-$sessionId'),
                              ref.watch(terminalSessionFamilyController(sessionId)).terminal,
                              controller: terminalController,
                              autofocus: true,
                            );
                          }).toList(),
                        ),
                      ),
                    // SizedBox(
                    //   height: MediaQuery.of(context).size.height - 200,
                    //   child: TerminalView(
                    //     terminalSession.terminal,
                    //     controller: terminalController,
                    //     autofocus: true,
                    //   ),
                    // ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
