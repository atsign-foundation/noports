import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/repository/contact_repository.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../utility/sizes.dart';

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
            return SizedBox(
              width: Sizes.p244.toFont,
              child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Sizes.p8.toFont),
                  ),
                  tileColor: kListTileColor,
                  leading: CircleAvatar(
                    radius: Sizes.p18.toFont,
                    backgroundColor: kPrimaryColor,
                    backgroundImage: snapshot.data!['image'] != null ? MemoryImage(snapshot.data!['image']) : null,
                  ),
                  title: Text(
                    snapshot.data?['name'] ?? '',
                    style: bodyMedium.copyWith(fontSize: bodyMedium.fontSize?.toFont),
                  ),
                  subtitle: Text(
                    contactRepo.atClientManager.atClient.getCurrentAtSign() ?? '',
                    style: bodySmall.copyWith(fontSize: bodySmall.fontSize?.toFont),
                  )),
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
