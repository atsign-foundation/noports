import 'package:flutter/material.dart';

import '../../../../utility/constants.dart';
import '../../../../utility/sizes.dart';

class ProfileFormCard extends StatelessWidget {
  const ProfileFormCard({
    required this.formFields,
    this.largeScreenRightPadding = Sizes.p233,
    super.key,
  });

  final List<Widget> formFields;

  /// The padding for the right side of the card on a screen larger than 600px
  final double largeScreenRightPadding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kProfileBackgroundColor,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: Sizes.p28,
            right: MediaQuery.of(context).size.width < 600 ? Sizes.p32 : largeScreenRightPadding,
            top: Sizes.p21,
            bottom: Sizes.p32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: formFields,
          ),
        ),
      ),
    );
  }
}
