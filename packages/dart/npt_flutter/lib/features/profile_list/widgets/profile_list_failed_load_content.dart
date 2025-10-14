import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/widgets/custom_card.dart';

class ProfileListFailedLoadContent extends StatelessWidget {
  const ProfileListFailedLoadContent({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return CustomCard.dashboardContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(strings.profilesFailedLoaded),
          ElevatedButton(
            child: Text(strings.reload),
            onPressed: () {
              context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
            },
          ),
        ],
      ),
    );
  }
}
