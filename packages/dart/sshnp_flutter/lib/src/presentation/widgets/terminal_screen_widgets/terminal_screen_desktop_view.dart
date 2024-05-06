import 'dart:async';
import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart' hide Intent;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_flutter/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';
import 'package:xterm/xterm.dart';

import '../../../repository/private_key_manager_repository.dart';
import '../../../repository/profile_private_key_manager_repository.dart';
import '../utility/custom_snack_bar.dart';

// * Once the onboarding process is completed you will be taken to this screen
class TerminalScreenDesktopView extends ConsumerStatefulWidget {
  const TerminalScreenDesktopView({super.key});

  @override
  ConsumerState<TerminalScreenDesktopView> createState() => _TerminalScreenDesktopViewState();
}

class _TerminalScreenDesktopViewState extends ConsumerState<TerminalScreenDesktopView> with TickerProviderStateMixin {
  final terminalController = TerminalController();
  double terminalFontSize = 14.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        final Map shellInfo = (GoRouterState.of(context).extra ?? {'runShell': false}) as Map;
        if (shellInfo['runShell']) {
          /// Issue a new session id
          final sessionId = ref.watch(terminalSessionController.notifier).createSession();

          /// Create the session controller for the new session id
          final sessionController = ref.watch(terminalSessionFamilyController(sessionId).notifier);

          sessionController.issueDisplayName(shellInfo['params'].profileName!);

          try {
            AtClient atClient = AtClientManager.getInstance().atClient;

            final profilePrivateKey = await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(
                shellInfo['params'].profileName ?? '');
            final privateKeyManager =
                await PrivateKeyManagerRepository.readPrivateKeyManager(profilePrivateKey.privateKeyNickname);

            final keyPair = privateKeyManager.toAtSshKeyPair();

            Sshnp? sshnp;
            SshnpResult? result = await runZonedGuarded<Future<SshnpResult?>>(() async {
              sshnp = Sshnp.dartPure(
                params: SshnpParams.merge(
                  shellInfo['params'],
                  SshnpPartialParams(
                    verbose: kDebugMode,
                    idleTimeout: 30,
                  ),
                ),
                atClient: atClient,
                identityKeyPair: keyPair,
              );

              sshnp!.progressStream?.listen((progress) {
                sessionController.write(progress);
                log(progress);
              });

              return await sshnp!.run().catchError((e) {
                CustomSnackBar.error(content: e.toString());
                throw 'Failed to start session';
              });
            }, (error, stack) {
              log('Error: $error', error: error, stackTrace: stack);
              sshnp = null;
              CustomSnackBar.error(content: 'Failed to initialize SSH No Ports');
              throw error.toString();
            });
            if (sshnp == null || result == null) {
              throw 'Failed to initialize SSH No Ports';
            }
            log(result.toString());
            if (result is SshnpError) {
              throw result;
            }

            if (result is SshnpCommand) {
              if (sshnp!.canRunShell) {
                SshnpRemoteProcess shell = await sshnp!.runShell();

                sessionController.startSession(
                  shell,
                  terminalTitle: '${shellInfo['sshnpdAtSign']}-${shellInfo['params'].device}',
                );
              }
            }
          } catch (e) {
            log('catch called');
            sessionController.dispose();

            log('error: ${e.toString()}');
            if (mounted) {
              log('mounted called');
              CustomSnackBar.error(content: e.toString());
            }
          }
        }
      },
    );
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

  void exitCallback(String sessionId) {
    log('exit intent called');
    closeSession(sessionId);
  }

  void nextTabCallback(TabController tabController, List<String> terminalList, int currentIndex) {
    log('next tab called');
    log(tabController.index.toString());
    log(terminalList.length.toString());
    if (tabController.index < (terminalList.length - 1)) {
      ref.read(terminalSessionController.notifier).setSession(terminalList[tabController.index + 1]);
      tabController.index++;
      log('current index is $currentIndex');
      log(tabController.index.toString());
    }
  }

  void previousTabCallback(TabController tabController, List<String> terminalList, int currentIndex) {
    log('previous tab called');
    log(tabController.index.toString());
    if (tabController.index > 0) {
      ref.read(terminalSessionController.notifier).setSession(terminalList[tabController.index - 1]);

      log(tabController.index.toString());
    }
  }

  void increaseFontSize() {
    log('a tab called');
    setState(() {
      terminalFontSize++;
    });
  }

  void decreaseFontSize() {
    log('a tab called');
    setState(() {
      terminalFontSize--;
    });
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
                      height: Sizes.p38,
                    ),
                    gapH24,
                    if (terminalList.isEmpty) Text(strings.noTerminalSessions, textScaler: const TextScaler.linear(2)),
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
                            key: Key('terminal-tab-$sessionId'),
                            child: Row(
                              children: [
                                Text(displayName),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => closeSession(sessionId),
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
                              shortcuts: <ShortcutActivator, VoidCallbackIntent>{
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.keyQ,
                                ): VoidCallbackIntent(() {
                                  exitCallback(sessionId);
                                }),
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.shift,
                                  LogicalKeyboardKey.arrowRight,
                                ): VoidCallbackIntent(() {
                                  nextTabCallback(tabController, terminalList, currentIndex);
                                }),
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.keyL,
                                ): VoidCallbackIntent(() {
                                  nextTabCallback(tabController, terminalList, currentIndex);
                                }),
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.shift,
                                  LogicalKeyboardKey.arrowLeft,
                                ): VoidCallbackIntent(() {
                                  previousTabCallback(tabController, terminalList, currentIndex);
                                }),
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.keyH,
                                ): VoidCallbackIntent(() {
                                  previousTabCallback(tabController, terminalList, currentIndex);
                                }),
                                LogicalKeySet(
                                  LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.equal,
                                ): VoidCallbackIntent(() {
                                  increaseFontSize();
                                }),
                                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.minus):
                                    VoidCallbackIntent(() {
                                  decreaseFontSize();
                                }),
                              },

                              // textStyle:
                              //     TerminalStyle.fromTextStyle(const TextStyle(fontFamily: '0xProtoNerdFontMono')),
                              // textStyle: TerminalStyle.fromTextStyle(const TextStyle(
                              //   fontFamily: 'GeistMonoNerdFont',
                              //   // fontSize: 14,
                              // )),
                              textStyle: TerminalStyle.fromTextStyle(
                                  TextStyle(fontFamily: 'IosevkaTermNerdFontPropo', fontSize: terminalFontSize
                                      // fontSize: 14,
                                      )),
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
