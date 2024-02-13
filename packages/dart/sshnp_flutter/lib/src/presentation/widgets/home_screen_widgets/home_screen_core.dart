import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/presentation/widgets/home_screen_widgets/home_screen_actions/new_profile_action.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../controllers/config_controller.dart';
import '../../../repository/authentication_repository.dart';
import '../../../utility/my_sync_progress_listener.dart';
import '../../../utility/sizes.dart';
import '../profile_screen_widgets/profile_bar/profile_bar.dart';
import '../utility/custom_snack_bar.dart';

class HomeScreenCore extends ConsumerStatefulWidget {
  const HomeScreenCore({super.key});

  @override
  ConsumerState<HomeScreenCore> createState() => _HomeScreenCoreState();
}

class _HomeScreenCoreState extends ConsumerState<HomeScreenCore> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        AtClientManager.getInstance().atClient.syncService.addProgressListener(MySyncProgressListener(ref));
        final isFirstRun = await AuthenticationRepository().checkFirstRun();
        log(isFirstRun.toString());
        if (isFirstRun) {
          CustomSnackBar.notification(
            content: 'Syncing profiles...',
            duration: const Duration(seconds: 3),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final profileNames = ref.watch(configListController);
    return profileNames.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, s) {
        return Text(e.toString());
      },
      data: (profiles) {
        if (profiles.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              gapH40,
              Text(
                'Get Started!',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: kHomeScreenGreyText),
              ),
              gapH16,
              Stack(
                children: [
                  Container(
                    height: Sizes.p185 + Sizes.p8,
                    width: Sizes.p244 + Sizes.p8,
                    decoration: BoxDecoration(
                      color: kProfileFormFieldColor,
                      borderRadius: BorderRadius.circular(Sizes.p8),
                    ),
                  ),
                  Card(
                    color: kInputChipBackgroundColor,
                    child: SizedBox(
                      height: Sizes.p185,
                      width: Sizes.p244,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Text(strings.createConnectionProfile, style: Theme.of(context).textTheme.bodyLarge),
                          Text(
                            strings.createConnectionProfileDesc,
                            textAlign: TextAlign.center,
                          ),
                          gapH14,
                          const NewProfileAction(),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          );
        }
        final sortedProfiles = profiles.toList();
        sortedProfiles.sort();
        return Column(
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
        );
      },
    );
  }
}

class ProfileExpansionPanel extends StatefulWidget {
  const ProfileExpansionPanel({required this.items, super.key});

  final List<String> items;

  @override
  State<ProfileExpansionPanel> createState() => _ProfileExpansionPanelState();
}

class _ProfileExpansionPanelState extends State<ProfileExpansionPanel> {
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.items.map((e) => false).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      expansionCallback: (panelIndex, isExpanded) {
        setState(() {
          _isExpanded[panelIndex] = !isExpanded;
        });
      },
      children: widget.items
          .map(
            (e) => ExpansionPanel(
              headerBuilder: (context, isExpanded) => ListTile(
                title: Text(e),
              ),
              body: const Text('body'),
              isExpanded: _isExpanded[widget.items.indexOf(e)],
            ),
          )
          .toList(),
    );
  }
}
