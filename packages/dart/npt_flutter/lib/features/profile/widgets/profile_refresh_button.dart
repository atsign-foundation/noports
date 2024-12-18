import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileRefreshButton extends StatelessWidget {
  const ProfileRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (BuildContext context, ProfileState state) => ElevatedButton(
        onPressed: () {
          context.read<ProfileBloc>().add(const ProfileLoadEvent(useCache: false));
        },
        child: Text(AppLocalizations.of(context)!.refresh),
      ),
    );
  }
}
