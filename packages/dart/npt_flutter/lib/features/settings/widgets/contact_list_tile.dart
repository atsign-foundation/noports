import 'package:flutter/material.dart';

import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';
import '../repository/contact_repository.dart';

class ContactListTile extends StatelessWidget {
  const ContactListTile({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final contactRepo = ContactsService.getInstance();

    final bodyMedium = Theme.of(context).textTheme.bodyMedium!;
    final bodySmall = Theme.of(context).textTheme.bodySmall!;
    return FutureBuilder(
        future: contactRepo.getCurrentAtsignContactDetails(),
        builder: ((context, snapshot) {
          if (snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Sizes.p10),
                  color: AppColor.cardColorDark,
                ),
                child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Sizes.p8.toFont),
                    ),
                    leading: CircleAvatar(
                      radius: Sizes.p18.toFont,
                      backgroundColor: AppColor.primaryColor,
                      backgroundImage: snapshot.data!['image'] != null ? MemoryImage(snapshot.data!['image']) : null,
                    ),
                    title: Text(
                      snapshot.data?['name'] ?? '',
                      style: bodyMedium.copyWith(fontSize: 8.toFont),
                    ),
                    subtitle: Text(
                      contactRepo.atClientManager.atClient.getCurrentAtSign() ?? '',
                      style: bodySmall.copyWith(fontSize: 8.toFont),
                    )),
              ),
            );
          } else {
            return const ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text('No Name'),
              subtitle: Text('No Atsign'),
            );
          }
        }));
  }
}
