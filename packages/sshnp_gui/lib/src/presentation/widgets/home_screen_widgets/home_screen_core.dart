import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/config_controller.dart';
import '../../../utility/sizes.dart';
import '../profile_screen_widgets/profile_bar/profile_bar.dart';

class HomeScreenCore extends ConsumerStatefulWidget {
  const HomeScreenCore({super.key});

  @override
  ConsumerState<HomeScreenCore> createState() => _HomeScreenCoreState();
}

class _HomeScreenCoreState extends ConsumerState<HomeScreenCore> {
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
