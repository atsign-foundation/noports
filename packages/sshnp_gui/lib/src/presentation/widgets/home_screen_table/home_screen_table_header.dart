import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/presentation/widgets/custom_table_cell.dart';

TableRow getHomeScreenTableHeader(AppLocalizations strings) => TableRow(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white))),
      children: <Widget>[
        CustomTableCell.text(text: strings.actions),
        CustomTableCell.text(text: strings.profileName),
        CustomTableCell.text(text: strings.sshnpdAtSign),
        CustomTableCell.text(text: strings.device),
        CustomTableCell.text(text: strings.host),
      ],
    );
