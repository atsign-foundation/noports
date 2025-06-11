import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:npt_flutter/features/authorisation/widgets/authorisation_app_bar_button.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/style_constants.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../styles/sizes.dart';

class NptAppBar extends StatefulWidget implements PreferredSizeWidget {
  const NptAppBar({
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.p150);

  @override
  State<NptAppBar> createState() => _NptAppBarState();
}

class _NptAppBarState extends State<NptAppBar> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final atsign = context.watch<OnboardingCubit>().getAtSign();
    return BlocBuilder<SubNavCubit, String>(
      builder: (context, state) {
        final isDashboard = state == HomeRoutes.dashboard;
        final isAuthorization = state == HomeRoutes.authorisation;
        return SizedBox(
          width: Sizes.p853,
          child: AppBar(
            titleSpacing: 0,
            leading: gap0,
            toolbarHeight: Sizes.p150,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                gapH40,
                Row(
                  children: [
                    gapW27,
                    SvgPicture.asset(
                      'assets/noports_logo.svg',
                      height: Sizes.p54,
                      width: Sizes.p175,
                    ),
                    gapW27,
                    Container(
                      color: AppColor.dividerColor,
                      height: Sizes.p38,
                      width: Sizes.p2,
                    ),
                    gapW27,
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = child.key == ValueKey(state)
                            ? Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation)
                            : Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(animation);
                        return SlideTransition(
                          position: offsetAnimation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      // The layoutBuilder ensures the children are left aligned.
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: Text(
                        routeName(state),
                        key: ValueKey(state),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
                gapH16,
                if (isDashboard) gapH40,
                if (!isDashboard && wrapperNav.currentState!.canPop())
                  SizedBox(
                    height: Sizes.p40,
                    child: TextButton.icon(
                      onPressed: () {
                        wrapperNav.currentState!.pop(context);
                      },
                      label: Text(
                        strings.back,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                      ),
                      style: StyleConstants.backButtonStyle,
                    ),
                  ),
              ],
            ),
            actions: [
              Container(
                padding: const EdgeInsets.only(top: Sizes.p8, bottom: Sizes.p8, left: Sizes.p8, right: Sizes.p0),
                decoration: BoxDecoration(
                  color: AppColor.outlinePaddingColor,
                  borderRadius: BorderRadius.circular(Sizes.p4),
                ),
                child: Row(
                  children: [
                    IgnorePointer(
                      ignoring: !isDashboard,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        opacity: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Sizes.p8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(Sizes.p4),
                          ),
                          height: 40,
                          child: Row(
                            children: [
                              Text(
                                atsign != null ? '@' : '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(color: AppColor.primaryColor, fontSize: Sizes.p20),
                              ),
                              Text(
                                atsign.replaceFirst('@', '') ?? '',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !isDashboard,
                      child: isDashboard
                          ? const AuthorisationAppBarButton()
                          : IconButton(
                              onPressed: () {},
                              icon: PhosphorIcon(
                                PhosphorIcons.key(),
                                color: isAuthorization ? AppColor.primaryColor : Colors.grey,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                ignoring: !isDashboard,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  opacity: isDashboard ? 1 : 0,
                  child: IconButton(
                    tooltip: strings.settings,
                    icon: const Icon(
                      Icons.settings_outlined,
                    ),
                    onPressed: () {
                      wrapperNav.currentState!.pushNamed(HomeRoutes.settings);
                    },
                  ),
                ),
              ),
              gapW103,
            ],
          ),
        );
      },
    );
  }
}
