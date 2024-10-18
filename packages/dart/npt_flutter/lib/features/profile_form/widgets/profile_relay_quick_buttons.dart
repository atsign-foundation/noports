import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/features/profile_form/widgets/profile_relay_at_sign_text_field.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/relay.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

class ProfileRelayQuickButtons extends StatelessWidget {
  const ProfileRelayQuickButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final ScrollController controller = ScrollController();
    return BlocSelector<ProfileBloc, ProfileState, String?>(selector: (ProfileState state) {
      if (state is ProfileLoadedState) {
        return state.profile.relayAtsign;
      }
      return null;
    }, builder: (BuildContext context, String? relayAtsign) {
      if (relayAtsign == null) return gap0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sizes.p50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.relay),
            gapH4,
            Text(
              strings.relayDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            gapH10,
            Scrollbar(
              controller: controller,
              thumbVisibility: true,
              child: Container(
                padding: const EdgeInsets.only(bottom: Sizes.p20),
                height: Sizes.p70,
                child: ListView(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  controller: controller,
                  children: [
                    ...RelayOptions.values.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(right: Sizes.p10),
                        child: CustomContainer.foreground(
                          key: Key(e.name),
                          child: SizedBox(
                            width: Sizes.p200,
                            height: Sizes.p50,
                            child: RadioListTile(
                              title: Text(e.regions),
                              value: e.relayAtsign,
                              groupValue: relayAtsign,
                              onChanged: (value) {
                                var bloc = context.read<ProfileBloc>();
                                bloc.add(ProfileEditEvent(
                                  profile: (bloc.state as ProfileLoadedState).profile.copyWith(relayAtsign: value),
                                ));
                              },
                            ),
                          ),
                        ),
                    const ProfileRelayAtSignTextField(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
