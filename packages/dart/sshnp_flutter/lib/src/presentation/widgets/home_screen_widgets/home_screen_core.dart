import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../controllers/config_controller.dart';
import '../../../repository/authentication_repository.dart';
import '../../../utility/my_sync_progress_listener.dart';
import '../../../utility/sizes.dart';
import '../profile_screen_widgets/profile_bar/profile_bar.dart';
import '../utility/custom_snack_bar.dart';
import 'home_screen_actions/home_screen_action_callbacks.dart';

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
          final emptyStateTextColor = Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white30);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              gapH40,
              // TODO: revisite uncommented code for pro version
              // Text(
              //   'Get Started!',
              //   style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: kHomeScreenGreyText),
              // ),
              // gapH16,
              // EmptyStateAltWidget(ref: ref, strings: strings),
              ListTile(
                title: Text(strings.getStartedTitle),
                subtitle: Text(strings.getStartedSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal)),
                tileColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Sizes.p36,
                  vertical: Sizes.p12,
                ),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => HomeScreenActionCallbacks.newProfileAction(ref, context),
              ),
              gapH24,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.profileName('other'),
                    style: emptyStateTextColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: Sizes.p36),
                    child: Text(
                      strings.commands,
                      style: emptyStateTextColor,
                    ),
                  ),
                ],
              ),
              const Divider(),
              gapH20,
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: kProfileBackgroundColor,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        strings.getStartedNoConnections,
                        style: emptyStateTextColor,
                      ),
                      gapH20,
                      SvgPicture.asset('assets/images/getting_started_empty_state.svg')
                    ],
                  ),
                ),
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
                Text(strings.profileName('other')),
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

class EmptyStateAltWidget extends StatelessWidget {
  const EmptyStateAltWidget({
    super.key,
    required this.ref,
    required this.strings,
  });

  final WidgetRef ref;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HomeScreenActionCallbacks.newProfileAction(ref, context),
      child: Stack(
        children: [
          // const NewProfileAction(),
          SvgPicture.asset(
            'assets/images/empty_profile_bg.svg',
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.68,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 60,
            left: 88,
            right: 88,
            child: Text(
              strings.createConnectionProfile,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          Positioned(
            top: 100,
            left: 88,
            right: 88,
            child: Text(
              strings.createConnectionProfileDesc,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
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
