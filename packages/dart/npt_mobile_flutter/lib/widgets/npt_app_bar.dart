import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_mobile_flutter/home_wrapper_widget.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/pages/pages.dart';
import 'package:npt_mobile_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/styles/app_color.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:npt_mobile_flutter/widgets/switch_atsign_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NptAppBar extends StatefulWidget implements PreferredSizeWidget {
  const NptAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<NptAppBar> createState() => _NptAppBarState();
}

class _NptAppBarState extends State<NptAppBar> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${packageInfo.version}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final atsign = context.watch<OnboardingCubit>().getAtSign();
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<SubNavCubit, String>(
      builder: (context, state) {
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.grey.withValues(alpha: 0.2),
          toolbarHeight: 56,
          titleSpacing: 0,
          title: Row(
            children: [
              // Compact logo section
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', width: 20, height: 20),
                    const SizedBox(width: 8),
                    Text(
                      StringConst.noPorts,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // User info and switch button
              const SwitchAtsignButton(),
            ],
          ),
        );
      },
    );
  }
}

class _NavTab extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _underlineAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _underlineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!widget.isActive) {
          setState(() => _isHovered = true);
          _animationController.forward();
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? AppColor.primaryColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Stack(
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive
                      ? Colors.black87
                      : _isHovered
                      ? Colors.black87
                      : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (!widget.isActive)
                Positioned(
                  bottom: -12,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _underlineAnimation,
                    builder: (context, child) {
                      return Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColor.primaryColor.withValues(
                            alpha: _underlineAnimation.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
