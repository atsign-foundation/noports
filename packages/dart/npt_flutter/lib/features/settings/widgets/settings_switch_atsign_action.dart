// import 'package:at_common_flutter/services/size_config.dart';
// import 'package:at_contact/at_contact.dart';
// import 'package:at_contacts_flutter/widgets/circular_contacts.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:npt_flutter/app.dart';
// import 'package:sshnp_flutter/src/controllers/authentication_controller.dart';
// import 'package:sshnp_flutter/src/presentation/widgets/settings_screen_widgets/settings_actions/settings_action_button.dart';
// import 'package:sshnp_flutter/src/presentation/widgets/utility/custom_snack_bar.dart';
// import 'package:sshnp_flutter/src/repository/authentication_repository.dart';
// import 'package:sshnp_flutter/src/repository/navigation_repository.dart';
// import 'package:sshnp_flutter/src/utility/constants.dart';

// class SettingsSwitchAtsignAction extends StatelessWidget {
//   const SettingsSwitchAtsignAction({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final strings = AppLocalizations.of(context)!;
//     return SettingsActionButton(
//       icon: Icons.logout_rounded,
//       title: strings.switchAtsign,
//       onTap: () async {
//         await showModalBottomSheet(
//             context: App.navState .currentContext!,
//             builder: (context) => const SwitchAtSignBottomSheet());
//       },
//     );
//   }
// }

// class SwitchAtSignBottomSheet extends ConsumerStatefulWidget {
//   const SwitchAtSignBottomSheet({super.key});

//   @override
//   ConsumerState<SwitchAtSignBottomSheet> createState() => _AtSignBottomSheetState();
// }

// class _AtSignBottomSheetState extends ConsumerState<SwitchAtSignBottomSheet> {
//   bool isLoading = false;

//   @override
//   void initState() {
//     ref.read(authenticationController.notifier).getAtSignList();

//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = ref.watch(authenticationController);
//     final strings = AppLocalizations.of(context)!;
//     SizeConfig().init(context);
//     return Stack(
//       children: [
//         Positioned(
//           child: BottomSheet(
//             onClosing: () {},
//             backgroundColor: Colors.transparent,
//             builder: (context) => ClipRRect(
//               borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
//               child: Container(
//                 height: 155.toHeight < 155 ? 155 : 150.toHeight,
//                 width: SizeConfig().screenWidth,
//                 color: kBackGroundColorDark,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                       child: Text(
//                         strings.switchAtsign,
//                       ),
//                     ),
//                     Container(
//                       height: 100.toHeight < 105 ? 110 : 100.toHeight,
//                       width: MediaQuery.of(context).size.width,
//                       color: kBackGroundColorDark,
//                       child: state.isLoading
//                           ? const CircularProgressIndicator()
//                           : Row(
//                               children: [
//                                 Expanded(
//                                     child: ListView.builder(
//                                   scrollDirection: Axis.horizontal,
//                                   itemCount: ref.watch(authenticationController).value!.length,
//                                   itemBuilder: (context, index) {
//                                     return FutureBuilder(
//                                         future: ref
//                                             .watch(authenticationController.notifier)
//                                             .getAtContact(state.value![index])
//                                             .then((value) => value),
//                                         builder: ((context, snapshot) {
//                                           if (snapshot.hasData) {
//                                             return GestureDetector(
//                                               onTap: isLoading
//                                                   ? () {}
//                                                   : () async {
//                                                       Navigator.pop(context);
//                                                       ref
//                                                           .watch(authenticationRepositoryProvider)
//                                                           .handleSwitchAtsign(state.value![index]);
//                                                     },
//                                               child: FittedBox(
//                                                 child: CircularContacts(contact: snapshot.data as AtContact),
//                                               ),
//                                             );
//                                           } else if (!snapshot.hasData) {
//                                             return const CircularProgressIndicator();
//                                           } else {
//                                             CustomSnackBar.error(content: strings.error);
//                                             return const SizedBox();
//                                           }
//                                         }));
//                                   },
//                                 )),
//                                 const SizedBox(
//                                   width: 20,
//                                 ),
//                                 GestureDetector(
//                                   onTap: () async {
//                                     setState(() {
//                                       isLoading = true;
//                                       Navigator.pop(context);
//                                     });
//                                     ref.watch(authenticationRepositoryProvider).handleSwitchAtsign(null);

//                                     setState(() {
//                                       isLoading = false;
//                                     });
//                                   },
//                                   child: Container(
//                                     margin: const EdgeInsets.only(right: 10),
//                                     height: 40,
//                                     width: 40,
//                                     child: Icon(Icons.add_circle_outline_outlined, size: 25.toFont),
//                                   ),
//                                 )
//                               ],
//                             ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
