import 'package:flutter/material.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';

/// White rounded card with a title row, matching the settings cards in
/// NoPorts Desktop.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(Sizes.p24),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        gapH4,
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColor.onSurfaceColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            gapH16,
            child,
          ],
        ),
      ),
    );
  }
}

/// Grey inset panel used inside cards for grouped controls.
class InsetPanel extends StatelessWidget {
  const InsetPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(Sizes.p16),
      decoration: BoxDecoration(
        color: AppColor.surfaceColor,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: child,
    );
  }
}

/// Coloured pill for statuses (running, stopped, pass, fail ...).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
  });

  const StatusPill.success({super.key, required this.label})
    : color = const Color(0xFF3E7D1F),
      background = AppColor.successColorAlt,
      icon = Icons.check_circle;

  const StatusPill.warning({super.key, required this.label})
    : color = const Color(0xFF9A5B00),
      background = AppColor.warningColorAlt,
      icon = Icons.warning_amber_rounded;

  const StatusPill.error({super.key, required this.label})
    : color = AppColor.errorColor,
      background = AppColor.errorColorAlt,
      icon = Icons.error;

  const StatusPill.neutral({super.key, required this.label})
    : color = AppColor.onSurfaceColor,
      background = AppColor.greyColor,
      icon = Icons.circle_outlined;

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p10,
        vertical: Sizes.p4,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            gapW4,
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple two column "label: value" row.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sizes.p4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColor.onSurfaceColor,
              ),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

/// Monospace, scrollable, selectable log panel.
class LogPanel extends StatefulWidget {
  const LogPanel({super.key, required this.text, this.height = 260});

  final String text;
  final double height;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  // Own controller so the always-visible scrollbar is not left hunting for
  // the enclosing ListView's position.
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      padding: const EdgeInsets.all(Sizes.p12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          child: SelectableText(
            widget.text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFD4D4D4),
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
