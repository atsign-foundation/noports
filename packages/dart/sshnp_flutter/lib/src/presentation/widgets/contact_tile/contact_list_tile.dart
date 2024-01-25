import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/repository/contact_repository.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../utility/sizes.dart';

class ContactListTile extends StatelessWidget {
  const ContactListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final contactRepo = ContactsService.getInstance();
    return FutureBuilder(
        future: contactRepo.getCurrentAtsignContactDetails(),
        builder: ((context, snapshot) {
          if (snapshot.hasData) {
            return SizedBox(
              width: Sizes.p320,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Sizes.p8),
                ),
                tileColor: kListTileColor,
                leading: CircleAvatar(
                  backgroundColor: kPrimaryColor,
                  backgroundImage: snapshot.data!['image'] != null ? MemoryImage(snapshot.data!['image']) : null,
                ),
                title: Text(snapshot.data?['name'] ?? ''),
                subtitle: Text(contactRepo.atClientManager.atClient.getCurrentAtSign() ?? ''),
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
