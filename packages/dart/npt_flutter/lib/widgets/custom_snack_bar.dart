import 'package:flutter/material.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CustomSnackBar {
  static void error({
    required String content,
    Duration duration = const Duration(seconds: 5),
  }) {
    final context = App.navState.currentContext!;
    final style = Theme.of(context).textTheme.bodyMedium;
    final strings = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.lineVertical(), color: AppColor.errorColor),
            gapW10,
            Icon(PhosphorIcons.xCircle(), color: AppColor.errorColor),
            gapW16,
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: '${strings.error}: ',
                  style: const TextStyle(color: AppColor.errorColor),
                  children: [TextSpan(text: content, style: style)],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        duration: duration,
      ),
    );
  }

  static void success({
    required String content,
    Duration duration = const Duration(seconds: 5),
  }) {
    final context = App.navState.currentContext!;
    final style = Theme.of(context).textTheme.bodyMedium;
    final strings = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.lineVertical(), color: AppColor.successColor),
            gapW10,
            Icon(PhosphorIcons.checkCircle(), color: AppColor.successColor),
            gapW16,
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: '${strings.success}: ',
                  style: const TextStyle(color: AppColor.successColor),
                  children: [TextSpan(text: content, style: style)],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        duration: duration,
      ),
    );
  }

  static void notification({
    required String content,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 5),
  }) {
    final context = App.navState.currentContext!;
    final style = Theme.of(context).textTheme.bodyMedium;
    final strings = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.lineVertical()),
            gapW10,
            Icon(PhosphorIcons.exclamationMark()),
            gapW16,
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: '${strings.info}: ',
                  style: const TextStyle(color: AppColor.onSurfaceColor),
                  children: [TextSpan(text: content, style: style)],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        action: action,
        duration: duration,
        // backgroundColor: kDataStorageColor,
      ),
    );
  }
}
