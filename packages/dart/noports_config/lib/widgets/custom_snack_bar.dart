import 'package:flutter/material.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';

/// Toasts styled like npt_flutter's: white, with a coloured bar and icon.
class CustomSnackBar {
  static void error(BuildContext context, String content) => _show(
    context,
    prefix: AppLocalizations.of(context).error,
    content: content,
    color: AppColor.errorColor,
    icon: Icons.cancel_outlined,
  );

  static void success(BuildContext context, String content) => _show(
    context,
    prefix: AppLocalizations.of(context).success,
    content: content,
    color: AppColor.successColor,
    icon: Icons.check_circle_outline,
  );

  static void info(BuildContext context, String content) => _show(
    context,
    prefix: AppLocalizations.of(context).info,
    content: content,
    color: AppColor.onSurfaceColor,
    icon: Icons.info_outline,
  );

  static void _show(
    BuildContext context, {
    required String prefix,
    required String content,
    required Color color,
    required IconData icon,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Container(width: 3, height: 28, color: color),
              gapW12,
              Icon(icon, color: color),
              gapW12,
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: '$prefix: ',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    children: [TextSpan(text: content, style: style)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
