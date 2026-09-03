import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';

const double kProfileColumnGap = Sizes.p10;
const double kProfileIconColumnWidth = Sizes.p40;
const double kProfileTextColumnMinWidth = Sizes.p80;

enum ProfileColumn {
  select(minWidth: kProfileIconColumnWidth),
  profileName(minWidth: kProfileTextColumnMinWidth),
  deviceName(minWidth: kProfileTextColumnMinWidth),
  serviceMapping(minWidth: kProfileTextColumnMinWidth),
  status(minWidth: kProfileIconColumnWidth),
  favorite(minWidth: kProfileIconColumnWidth),
  menu(minWidth: kProfileIconColumnWidth);

  const ProfileColumn({required this.minWidth});

  final double minWidth;

  static List<ProfileColumn> resizableFor(PreferredViewLayout layout) {
    return switch (layout) {
      PreferredViewLayout.minimal => const [profileName, status],
      PreferredViewLayout.sshStyle => const [
        profileName,
        deviceName,
        serviceMapping,
        status,
      ],
    };
  }

  static Map<ProfileColumn, double> defaultFractionsFor(
    PreferredViewLayout layout,
  ) {
    return switch (layout) {
      PreferredViewLayout.minimal => const {profileName: 0.5, status: 0.5},
      PreferredViewLayout.sshStyle => const {
        profileName: 0.24,
        deviceName: 0.24,
        serviceMapping: 0.24,
        status: 0.28,
      },
    };
  }
}
