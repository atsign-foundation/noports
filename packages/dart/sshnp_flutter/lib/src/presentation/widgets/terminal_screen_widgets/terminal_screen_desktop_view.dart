import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnp_flutter/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';
import 'package:xterm/xterm.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreenDesktopView extends ConsumerStatefulWidget {
  const TerminalScreenDesktopView({Key? key}) : super(key: key);

  @override
  ConsumerState<TerminalScreenDesktopView> createState() => _TerminalScreenDesktopViewState();
}

class _TerminalScreenDesktopViewState extends ConsumerState<TerminalScreenDesktopView> with TickerProviderStateMixin {
  final terminalController = TerminalController();

  @override
  void dispose() {
    terminalController.dispose();
    super.dispose();
  }

  void closeSession(String sessionId, List<String> terminalList) {
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
                                  onPressed: () => closeSession(sessionId, terminalList),
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
                              autoResize: true,
                            );
                          }).toList(),
                        ),
                      ),
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
