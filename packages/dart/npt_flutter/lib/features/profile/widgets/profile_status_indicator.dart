import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileStatusIndicator extends StatelessWidget {
  const ProfileStatusIndicator({required this.width, super.key});
  final double width;
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return SizedBox(
      width: width,
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (BuildContext context, ProfileState state) {
          log(state.runtimeType.toString());
          if (state is ProfileLoading) {
            return StatusMessage(
              tooltip: strings.profileStatusLoading,
              status: strings.profileStatusLoading,
              color: Colors.grey,
              icon: PhosphorIcons.circleDashed(),
            );
          }

          if (state is ProfileLoaded) {
            return StatusMessage(
              tooltip: strings.profileStatusLoadedMessage,
              status: strings.profileStatusLoaded,
              color: Colors.grey,
              icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
              onPressed: () {
                context.read<ProfileBloc>().add(const ProfileStartEvent());
              },
            );
          }
          if (state is ProfileFailedSave) {
            return StatusMessage(
              tooltip: strings.profileFailedSaveMessage,
              status: strings.profileStatusFailedSave,
              color: Colors.red,
              icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
              onPressed: () {
                context.read<ProfileBloc>().add(const ProfileStartEvent());
              },
            );
          }
          if (state is ProfileFailedStart) {
            return StatusMessage(
              tooltip: state.reason ?? strings.profileFailedUnknownMessage,
              status: strings.profileStatusFailedStart,
              color: Colors.red,
              icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
              onPressed: () {
                context.read<ProfileBloc>().add(const ProfileStartEvent());
              },
            );
          }
          if (state is ProfileFailedLoad) {
            return StatusMessage(
              tooltip: strings.profileFailedUnknownMessage,
              status: strings.profileStatusFailedLoad,
              color: Colors.red,
              icon: PhosphorIcons.circle(PhosphorIconsStyle.fill),
            );
          }
          if (state is ProfileStarting) {
            return StatusMessage(
              tooltip: state.status ?? strings.profileFailedUnknownMessage,
              status: strings.profileStatusStarting,
              color: Colors.grey,
              icon: PhosphorIcons.circleDashed(),
              showSpinner: true,
            );
          }
          if (state is ProfileStarted) {
            return StatusMessage(
              tooltip: strings.profileStatusStartedMessage,
              status: strings.profileStatusStarted,
              color: Colors.green,
              icon: PhosphorIcons.stop(PhosphorIconsStyle.fill),
              onPressed: () {
                context.read<ProfileBloc>().add(const ProfileStopEvent());
              },
            );
          }
          if (state is ProfileStopping) {
            return StatusMessage(
              tooltip: strings.profileStatusStopping,
              status: strings.profileStatusStopping,
              color: Colors.grey,
              icon: PhosphorIcons.circleDashed(),
              showSpinner: true,
            );
          }

          return gap0;
        },
      ),
    );
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.tooltip,
    required this.status,
    required this.color,
    required this.icon,
    this.onPressed,
    this.showSpinner = false,
    super.key,
  });

  static const double iconSize = Sizes.p20;
  static const double statusTextMinWidth = Sizes.p40;

  final String tooltip;
  final String status;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool showSpinner;
  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = showSpinner
        ? const SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          )
        : onPressed != null
        ? InkWell(
            borderRadius: BorderRadius.circular(Sizes.p12),
            onTap: onPressed,
            child: PhosphorIcon(icon, color: color, size: iconSize),
          )
        : PhosphorIcon(icon, color: color, size: iconSize);

    return Tooltip(
      verticalOffset: Sizes.p10n,
      message: tooltip,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showStatus =
              constraints.maxWidth - iconSize - Sizes.p8 >= statusTextMinWidth;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              if (showStatus) ...[
                gapW8,
                Flexible(
                  child: Text(
                    status,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
