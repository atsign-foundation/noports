import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/presentation/widgets/custom_table_cell.dart';

class HomeScreenTableProfileNameText extends StatelessWidget {
  final AsyncValue<SSHNPParams> params;
  const HomeScreenTableProfileNameText(this.params, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return params.when(
      data: (p) => CustomTableCell.text(text: p.profileName!),
      error: (e, s) =>
          const CustomTableCell.text(text: 'Error fetching data...'),
      loading: () => const CustomTableCell.text(text: '...'),
    );
  }
}

class HomeScreenTableSshnpdAtSignText extends StatelessWidget {
  final AsyncValue<SSHNPParams> params;
  const HomeScreenTableSshnpdAtSignText(this.params, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return params.when(
      data: (p) => CustomTableCell.text(text: p.sshnpdAtSign!),
      error: (e, s) =>
          const CustomTableCell.text(text: 'Error fetching data...'),
      loading: () => const CustomTableCell.text(text: '...'),
    );
  }
}

class HomeScreenTableDeviceText extends StatelessWidget {
  final AsyncValue<SSHNPParams> params;
  const HomeScreenTableDeviceText(this.params, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return params.when(
      data: (p) => CustomTableCell.text(text: p.device),
      error: (e, s) =>
          const CustomTableCell.text(text: 'Error fetching data...'),
      loading: () => const CustomTableCell.text(text: '...'),
    );
  }
}

class HomeScreenTableHostText extends StatelessWidget {
  final AsyncValue<SSHNPParams> params;
  const HomeScreenTableHostText(this.params, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return params.when(
      data: (p) => CustomTableCell.text(text: p.host!),
      error: (e, s) =>
          const CustomTableCell.text(text: 'Error fetching data...'),
      loading: () => const CustomTableCell.text(text: '...'),
    );
  }
}
