import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

class CustomListTile extends StatelessWidget {
  const CustomListTile({super.key, required this.iconData, required this.title, required this.subtitle, this.onTap});

  const CustomListTile.discord(
      {this.iconData = Icons.discord,
      this.title = 'Discord',
      this.subtitle = 'Join our server for help',
      Key? key,
      required this.onTap})
      : super(key: key);
  const CustomListTile.email(
      {this.iconData = Icons.email,
      this.title = 'Email',
      this.subtitle = 'Guranteed quick response',
      required this.onTap,
      Key? key})
      : super(key: key);
  const CustomListTile.keyManagement(
      {this.iconData = Icons.key_outlined,
      this.title = 'SSH Key Management',
      this.subtitle = 'Edit, add and delete SSH Keys',
      required this.onTap,
      Key? key})
      : super(key: key);
  const CustomListTile.deleteYourKey(
      {this.iconData = Icons.delete_outline,
      this.title = 'Delete Your Key',
      this.subtitle = 'Delete your active atKey',
      required this.onTap,
      Key? key})
      : super(key: key);

  final IconData iconData;
  final String title;
  final String subtitle;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: kIconColorBackground),
        onPressed: onTap,
        child: Icon(
          iconData,
          color: kIconColorDark,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: kTextColorDark),
      ),
      onTap: onTap,
    );
  }
}
