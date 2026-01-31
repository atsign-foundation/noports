import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/logging/logging.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';

class DebugDumpLogsButton extends StatelessWidget {
  const DebugDumpLogsButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return gap0;
    return ElevatedButton(
      child: Text(AppLocalizations.of(context)!.debugDumpLogTitle),
      onPressed: () {
        var list = context.read<LogsCubit>().logs;
        for (final line in list) {
          if (kDebugMode) {
            print(line);
          }
        }
      },
    );
  }
}
