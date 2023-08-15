// import 'package:flutter/material.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../controllers/at_data_controller.dart';
// import '../domain.dart/at_data.dart';
// import '../utils/sizes.dart';

// class DeleteAlertDialog extends ConsumerWidget {
//   const DeleteAlertDialog({required this.atData, super.key});
//   final AtData atData;

//   @override
//   Widget build(
//     BuildContext context,
//     WidgetRef ref,
//   ) {
//     final strings = AppLocalizations.of(context)!;
//     final data = ref.watch(atDataControllerProvider);

//     return AlertDialog(
//       title: Text(strings.warning),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(strings.warningMessage(
//             atData.atKey.toString(),
//           )),
//           gapH12,
//           Text.rich(
//             TextSpan(
//               children: [
//                 TextSpan(
//                   text: strings.note,
//                   style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
//                 ),
//                 TextSpan(
//                   text: strings.noteMessage,
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//       actions: [
//         OutlinedButton(
//           onPressed: () => Navigator.of(context).pop(false),
//           child: Text(strings.cancelButton,
//               style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline)),
//         ),
//         ElevatedButton(
//             onPressed: () async {
//               await ref.read(atDataControllerProvider.notifier).delete(atData);

//               if (context.mounted) Navigator.of(context).pop();
//             },
//             style: Theme.of(context).elevatedButtonTheme.style!.copyWith(
//                   backgroundColor: MaterialStateProperty.all(Colors.black),
//                 ),
//             child: !data.isLoading
//                 ? Text(
//                     strings.deleteButton,
//                     style: Theme.of(context)
//                         .textTheme
//                         .bodyLarge!
//                         .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
//                   )
//                 : const CircularProgressIndicator(
//                     color: Colors.white,
//                   )),
//       ],
//     );
//   }
// }
