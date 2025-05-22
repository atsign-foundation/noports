import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:npt_flutter/widgets/custom_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientAtsignDescriptionWidget extends StatefulWidget {
  const ClientAtsignDescriptionWidget({required this.width, super.key});

  final double width;

  @override
  State<ClientAtsignDescriptionWidget> createState() => _ClientAtsignDescriptionWidgetState();
}

class _ClientAtsignDescriptionWidgetState extends State<ClientAtsignDescriptionWidget> {
  bool visibility = false;

  void visitRegistarSite() async {
    final Uri url = Uri.parse('https://my.noports.com/no-ports-invite/14dayfreetrial');
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
              Icon(
                PhosphorIcons.info(),
                color: AppColor.primaryColor,
              ),
              gapW14,
              Text(strings.whatIsClientAtsign, style: const TextStyle(color: AppColor.primaryColor)),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    visibility = !visibility;
                  });
                },
                icon: Icon(PhosphorIcons.caretDown()),
                color: AppColor.primaryColor,
              )
            ],
          ),
          visibility ? gapH14 : gap0,
          Visibility(
            maintainAnimation: true,
            maintainState: true,
            visible: visibility,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Sizes.p16,
              children: [
                Expanded(
                  child: CustomContainer.foreground(
                    padding: Sizes.p16,
                    width: width / 2.1,
                    height: Sizes.p322,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.clientAtsignDescription,
                          textAlign: TextAlign.center,
                          style: bodyMedium!.copyWith(
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(strings.myNoPortsMsg + StringConst.myNoPorts),
                            IconButton(
                              icon: Icon(
                                PhosphorIcons.arrowUpRight(),
                                color: AppColor.primaryColor,
                              ),
                              onPressed: visitMyNoPorts,
                            ),
                          ],
                        ),
                        gapH25,
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Card(
                              elevation: Sizes.p15,
                              child: SvgPicture.asset(
                                'assets/my_noports_main.svg',
                                width: width / 3.2,
                              ),
                            ),
                            Positioned(
                              top: (width / -40),
                              child: Card(
                                margin: EdgeInsets.zero,
                                shape: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(Sizes.p8),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                                elevation: Sizes.p15,
                                child: SvgPicture.asset(
                                  'assets/my_noports_sec_2.svg',
                                  height: (width / Sizes.p8) / 2.3,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: (width / Sizes.p15),
                              left: width / Sizes.p15,
                              child: RichText(
                                text: const TextSpan(
                                  text: StringConst.ampersand,
                                  style: TextStyle(color: AppColor.primaryColor, fontSize: 10),
                                  children: [
                                    TextSpan(
                                      text: StringConst.atsign_client,
                                      style: TextStyle(color: Colors.black, fontSize: Sizes.p10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  strings.or,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(color: AppColor.primaryColor),
                ),
                Expanded(
                  child: CustomContainer.foreground(
                    width: width / 2.1,
                    height: Sizes.p322,
                    decorationImage: const DecorationImage(
                      alignment: Alignment.centerRight,
                      image: AssetImage('assets/at.png'),
                      fit: BoxFit.contain,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.atsignUncreated,
                          style: bodyMedium.copyWith(color: AppColor.primaryColor),
                        ),
                        gapH10,
                        SizedBox(
                          width: Sizes.p150,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(color: AppColor.primaryColor, width: Sizes.p2),
                                borderRadius: BorderRadius.circular(Sizes.p10),
                              ),
                            ),
                            onPressed: visitRegistarSite,
                            child: Text(strings.register),
                          ),
                        ),
                      ],
                    ),
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
