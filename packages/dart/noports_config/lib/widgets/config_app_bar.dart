import 'package:flutter/material.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Top bar in the style of NoPorts Desktop: logo, wordmark, version chip
/// and a row of underlined tabs.
class ConfigAppBar extends StatefulWidget implements PreferredSizeWidget {
  const ConfigAppBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<ConfigAppBar> createState() => _ConfigAppBarState();
}

class _ConfigAppBarState extends State<ConfigAppBar> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return AppBar(
      elevation: 1,
      shadowColor: Colors.grey.withValues(alpha: 0.2),
      toolbarHeight: 64,
      titleSpacing: 0,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      title: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sizes.p24),
            child: Row(
              children: [
                Image.asset('assets/logo.png', width: 24, height: 24),
                gapW8,
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: strings.appName,
                        style: titleStyle?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: ' ${strings.appSubtitle}',
                        style: titleStyle?.copyWith(
                          fontWeight: FontWeight.w300,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                gapW8,
                if (_version.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sizes.p6,
                      vertical: Sizes.p2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(Sizes.p4),
                    ),
                    child: Text(
                      _version,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.tabs.length; i++)
                      NavTab(
                        label: widget.tabs[i],
                        isActive: i == widget.selected,
                        onTap: () => widget.onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: Sizes.p24),
              child: widget.trailing,
            ),
        ],
      ),
    );
  }
}

class NavTab extends StatefulWidget {
  const NavTab({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<NavTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final underline = widget.isActive
        ? AppColor.primaryColor
        : _hovered
        ? AppColor.primaryColor.withValues(alpha: 0.5)
        : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: Sizes.p12,
            vertical: Sizes.p12,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: underline, width: 2)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isActive || _hovered
                  ? Colors.black87
                  : Colors.grey[600],
              fontSize: 13,
              fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
