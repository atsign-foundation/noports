import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/widgets/profile_header_column.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/widgets/loader_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileHeaderView extends StatelessWidget {
  const ProfileHeaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return BlocBuilder<ProfileListBloc, ProfileListState>(
      builder: (context, state) {
        if (state is ProfileListInitial) {
          context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
        }
        switch (state) {
          case ProfileListInitial _:
          case ProfileListLoading _:
            return const Row(
              children: [LoaderBar(), ProfileListRefreshButton()],
            );

          case ProfileListFailedLoad _:
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(strings.errorProfileLoadFailed),
                const ProfileListRefreshButton(),
              ],
            );

          case ProfileListLoaded _:
            return BlocSelector<
              SettingsBloc,
              SettingsState,
              PreferredViewLayout?
            >(
              selector: (SettingsState state) {
                if (state is SettingsLoadedState) {
                  return state.settings.viewLayout;
                }
                return null;
              },
              builder: (BuildContext context, PreferredViewLayout? viewLayout) {
                if (viewLayout == null) {
                  return const Center(child: Spinner());
                }
                return CustomCard.profileHeader(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sizes.p10),
                    child: ProfileColumnsRow(
                      layout: viewLayout,
                      select: const ProfileSelectAllBox(),
                      cellBuilder: (ProfileColumn column, double width) =>
                          ProfileHeaderColumn(title: _title(strings, column)),
                      dividerBuilder:
                          (
                            ProfileColumn column,
                            double width,
                            double availableWidth,
                          ) => ProfileColumnDivider(
                            key: ValueKey<ProfileColumn>(column),
                            layout: viewLayout,
                            column: column,
                            width: width,
                            availableWidth: availableWidth,
                          ),
                      favorite: gap0,
                      menu: gap0,
                    ),
                  ),
                );
              },
            );
        }
      },
    );
  }

  String _title(AppLocalizations strings, ProfileColumn column) {
    return switch (column) {
      ProfileColumn.profileName => strings.profileName,
      ProfileColumn.deviceName => strings.deviceName,
      ProfileColumn.serviceMapping => strings.serviceMapping,
      ProfileColumn.status => strings.status,
      ProfileColumn.select ||
      ProfileColumn.favorite ||
      ProfileColumn.menu => '',
    };
  }
}
