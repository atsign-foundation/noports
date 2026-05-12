import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';

class ProfileRelayAtsignTextField extends StatefulWidget {
  const ProfileRelayAtsignTextField({super.key});

  @override
  State<ProfileRelayAtsignTextField> createState() =>
      _ProfileRelayAtsignTextFieldState();
}

class _ProfileRelayAtsignTextFieldState
    extends State<ProfileRelayAtsignTextField> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, Atsign?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) {
          return state.profile.relayAtsign;
        }
        return null;
      },
      builder: (BuildContext context, Atsign? relayAtsign) {
        if (relayAtsign == null) return gap0;
        Future.microtask(
          () => controller.value = TextEditingValue(
            text: relayAtsign,
            selection: TextSelection.collapsed(offset: relayAtsign.length),
          ),
        );
        return SizedBox(
          width: Sizes.p200,
          height: Sizes.p70,
          child: TextFormField(
            controller: controller,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.custom,
              errorMaxLines: 2,
            ),
            validator: FormValidator.validateEmptyRelayField,
            onChanged: (value) {
              value = value.toAtsign();
              controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
              var bloc = context.read<ProfileBloc>();
              bloc.add(
                ProfileEditEvent(
                  profile: (bloc.state as ProfileLoadedState).profile.copyWith(
                    relayAtsign: value.toAtsign(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
