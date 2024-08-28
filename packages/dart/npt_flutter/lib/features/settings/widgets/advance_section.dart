import 'package:flutter/material.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';
import '../../logging/widgets/enable_logs_box.dart';
import '../../logging/widgets/export_logs_button.dart';

class AdvanceSection extends StatelessWidget {
  const AdvanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Icon(Icons.apps),
            Text(" Advanced"),
          ],
        ),
        gapH16,
        CustomContainer.background(
          child: Column(
            children: [
              Row(children: [
                Text("Enable Logging"),
                EnableLogsBox(),
                gapW20,
                ExportLogsButton(),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
