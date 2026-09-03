import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/cubit/profile_columns_cubit.dart';
import 'package:npt_flutter/features/profile_list/models/profile_column.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileColumnDivider extends StatefulWidget {
  const ProfileColumnDivider({
    super.key,
    required this.layout,
    required this.column,
    required this.width,
    required this.availableWidth,
  });

  final PreferredViewLayout layout;
  final ProfileColumn column;
  final double width;
  final double availableWidth;

  @override
  State<ProfileColumnDivider> createState() => _ProfileColumnDividerState();
}

class _ProfileColumnDividerState extends State<ProfileColumnDivider> {
  bool _hovering = false;
  bool _dragging = false;
  double _dragStartX = 0;
  double _dragStartWidth = 0;

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartWidth = widget.width;
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    context.read<ProfileColumnsCubit>().resizeColumn(
      layout: widget.layout,
      column: widget.column,
      width: _dragStartWidth + (details.globalPosition.dx - _dragStartX),
      availableWidth: widget.availableWidth,
    );
  }

  void _onDragStop() {
    if (_dragging) setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: (_) => _onDragStop(),
        onHorizontalDragCancel: _onDragStop,
        child: SizedBox(
          width: kProfileColumnGap,
          height: Sizes.p40,
          child: Center(
            child: Container(
              width: active ? Sizes.p2 : Sizes.p1,
              margin: const EdgeInsets.symmetric(vertical: Sizes.p8),
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : AppColor.dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
