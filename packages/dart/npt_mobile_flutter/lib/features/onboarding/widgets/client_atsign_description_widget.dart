import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/app_color.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:npt_mobile_flutter/widgets/custom_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientAtsignDescriptionWidget extends StatefulWidget {
  const ClientAtsignDescriptionWidget({required this.width, super.key});

  final double width;

  @override
  State<ClientAtsignDescriptionWidget> createState() =>
      _ClientAtsignDescriptionWidgetState();
}

class _ClientAtsignDescriptionWidgetState
    extends State<ClientAtsignDescriptionWidget> {
  bool visibility = false;

  void visitRegistarSite() async {
    final Uri url = Uri.parse('https://my.noports.com/no-ports-plans/');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  void visitMyNoPorts() async {
    final Uri url = Uri.parse('https://my.noports.com/');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.60;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    return CustomContainer.background(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.info(), color: AppColor.primaryColor),
              gapW14,
              Flexible(
                child: Text(
                  strings.whatIsClientAtsign,
                  style: const TextStyle(color: AppColor.primaryColor),
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    visibility = !visibility;
                  });
                },
                icon: Icon(PhosphorIcons.caretDown()),
                color: AppColor.primaryColor,
              ),
            ],
          ),
          visibility ? gapH14 : gap0,
          Visibility(
            maintainAnimation: true,
            maintainState: true,
            visible: visibility,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Sizes.p16,
              children: [
                CustomContainer.foreground(
                  padding: Sizes.p12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        strings.clientAtsignDescription,
                        textAlign: TextAlign.center,
                        style: bodyMedium!.copyWith(color: Colors.black),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      gapH8,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.myNoPortsMsg +
                                StringConst.managementPortal,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              PhosphorIcons.arrowUpRight(),
                              color: AppColor.primaryColor,
                              size: 20,
                            ),
                            onPressed: visitMyNoPorts,
                          ),
                        ],
                      ),
                      gapH12,
                      SizedBox(
                        height: Sizes.p150,
                        child: Material(
                          color: Colors.transparent,
                          elevation: Sizes.p15,
                          child: SvgPicture.asset(
                            'assets/management_portal.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  strings.or,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: AppColor.primaryColor,
                  ),
                ),
                CustomContainer.foreground(
                  padding: Sizes.p12,
                  decorationImage: const DecorationImage(
                    alignment: Alignment.centerRight,
                    image: AssetImage('assets/at.png'),
                    fit: BoxFit.contain,
                    opacity: 0.1,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        strings.atsignUncreated,
                        style: bodyMedium.copyWith(
                          color: AppColor.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      gapH10,
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              color: AppColor.primaryColor,
                              width: Sizes.p2,
                            ),
                            borderRadius: BorderRadius.circular(Sizes.p10),
                          ),
                        ),
                        onPressed: visitRegistarSite,
                        child: Text(strings.register),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
