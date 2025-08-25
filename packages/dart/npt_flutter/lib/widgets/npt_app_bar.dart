import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/pages/pages.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NptAppBar extends StatefulWidget implements PreferredSizeWidget {
  const NptAppBar({
    super.key,
  });

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
    return BlocBuilder<SubNavCubit, String>(
      builder: (context, state) {
        return AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.grey.withValues(alpha: 0.2),
          toolbarHeight: 64,
          titleSpacing: 0,
          leading: const SizedBox.shrink(),
          leadingWidth: 0,
          title: Row(
            children: [
              // Logo and version section
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'NoPorts',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              TextSpan(
                                text: 'Desktop',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _version.isNotEmpty ? _version : 'v1.4.0',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Navigation tabs in center
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavTab(
                          label: 'Connections',
                          isActive: state == HomeRoutes.dashboard,
                          onTap: () {
                            if (state != HomeRoutes.dashboard) {
                              wrapperNav.currentState!.pushNamedAndRemoveUntil(
                                HomeRoutes.dashboard, 
                                (route) => false,
                              );
                            }
                          },
                        ),
                        _NavTab(
                          label: 'Policy',
                          isActive: state == HomeRoutes.policyManager,
                          onTap: () {
                            if (state != HomeRoutes.policyManager) {
                              final PolicyPageArguments args = PolicyPageArguments(atsign);
                              wrapperNav.currentState!.pushNamed(HomeRoutes.policyManager, arguments: args);
                            }
                          },
                        ),
                        _NavTab(
                          label: 'Authenticator',
                          isActive: state == HomeRoutes.authorisation,
                          onTap: () {
                            if (state != HomeRoutes.authorisation) {
                              wrapperNav.currentState!.pushNamed(HomeRoutes.authorisation);
                            }
                          },
                        ),
                        _NavTab(
                          label: 'Settings',
                          isActive: state == HomeRoutes.settings,
                          onTap: () {
                            if (state != HomeRoutes.settings) {
                              wrapperNav.currentState!.pushNamed(HomeRoutes.settings);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // User section on right
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColor.primaryColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/At.svg',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        atsign.isNotEmpty ? atsign.replaceFirst('@', '') : 'user',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    _underlineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
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
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
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
                          color: AppColor.primaryColor.withValues(alpha: _underlineAnimation.value),
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
