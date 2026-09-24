import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Drag grip for a row or folder header. A null [index] renders an empty
/// slot of the same [width] so items that can't be dragged still line up.
class ProfileDragHandle extends StatelessWidget {
  static const double width = Sizes.p24;

  final int? index;
  final bool enabled;

  const ProfileDragHandle({
    required this.index,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (index == null) return const SizedBox(width: width);
    return ReorderableDragStartListener(
      index: index!,
      enabled: enabled,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          key: const Key('ProfileDragHandle'),
          width: width,
          height: Sizes.p24,
          child: Center(
            child: PhosphorIcon(
              PhosphorIcons.dotsSixVertical(),
              size: Sizes.p16,
              color: Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}
