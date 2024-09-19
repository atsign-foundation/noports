import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/logging/logging.dart';

class EnableLogsBox extends StatelessWidget {
  const EnableLogsBox({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnableLoggingCubit, bool>(
      builder: (BuildContext context, bool checked) {
        return Checkbox(
          value: checked,
          onChanged: (bool? value) {
            switch (value) {
              case null:
                return;
              case true:
                context.read<EnableLoggingCubit>().enable();
              case false:
                context.read<EnableLoggingCubit>().disable();
            }
          },
        );
      },
    );
  }
}
