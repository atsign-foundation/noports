import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';
import '../repository/contact_repository.dart';

class ContactListTile extends StatelessWidget {
  const ContactListTile({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init();
    final contactRepo = ContactsService.getInstance();
    final strings = AppLocalizations.of(context)!;

    final bodySmall = Theme.of(context).textTheme.bodySmall!;
    return FutureBuilder(
        future: contactRepo.getCurrentAtsignContactDetails(),
        builder: ((context, snapshot) {
          if (snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.p15),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Sizes.p10),
                  color: AppColor.cardColorDark,
                ),
                child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: Sizes.p30),
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Sizes.p8.toFont),
                    ),
                    title: Text(
                      contactRepo.atClientManager.atClient.getCurrentAtSign() ?? '',
                      style: bodySmall.copyWith(fontSize: 8.toFont),
                    )),
              ),
            );
          } else {
            return ListTile(
              title: Text(strings.noName),
              subtitle: Text(strings.noAtsign),
            );
          }
        }));
  }
}
