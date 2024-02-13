import 'dart:developer';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          return const Text('No SSHNP Configurations Found');
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
