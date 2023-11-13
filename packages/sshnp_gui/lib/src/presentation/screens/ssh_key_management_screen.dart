import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_actions/home_screen_actions.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/profile_bar.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

// * Once the onboarding process is completed you will be taken to this screen
class SshKeyManagementScreen extends ConsumerStatefulWidget {
  const SshKeyManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SshKeyManagementScreen> createState() => _SshKeyManagementScreenState();
}

class _SshKeyManagementScreenState extends ConsumerState<SshKeyManagementScreen> {
  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below

    final strings = AppLocalizations.of(context)!;
    final profileNames = ref.watch(configListController);

    return Scaffold(
      body: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.currentConnections,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(strings.currentConnectionsDescription),
                          ],
                        ),
                        gapW16,
                        const HomeScreenActions(),
                      ],
                    ),
                    gapH8,
                    profileNames.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, s) {
                        return Text(e.toString());
                      },
                      data: (profiles) {
                        if (profiles.isEmpty) {
                          return const Text('No SSHNP Configurations Found');
                        }
                        final sortedProfiles = profiles.toList();
                        sortedProfiles.sort();
                        return Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(strings.profileName),
                                  Padding(
                                    padding: const EdgeInsets.only(right: Sizes.p36),
                                    child: Text(strings.commands),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView(
                                  children: sortedProfiles.map((profileName) => ProfileBar(profileName)).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreenBodyWrapper extends StatelessWidget {
  const HomeScreenBodyWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
