import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_table/custom_table_cell.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_delete_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_edit_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_run_action.dart';

class HomeScreenTableActions extends StatelessWidget {
  final AsyncValue<SSHNPParams> params;
  const HomeScreenTableActions(this.params, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return params.when(
      data: (p) => CustomTableCell(
        child: Row(
          children: [
            HomeScreenRunAction(p),
            HomeScreenEditAction(p),
            HomeScreenDeleteAction(p),
          ],
        ),
      ),
      error: (e, s) =>
          const CustomTableCell.text(text: 'Error fetching data...'),
      loading: () => const CustomTableCell.text(text: '...'),
    );
  }
}
