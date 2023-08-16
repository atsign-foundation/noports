// import 'dart:developer';
// import 'dart:io';

// import 'package:at_client_mobile/at_client_mobile.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:sshnoports/common/utils.dart';
// import 'package:sshnoports/sshnp/sshnp.dart';

// /// A Controller class that controls the UI update when the [AtDataRepository] methods are called.
// class HomeScreenController extends StateNotifier<AsyncValue<List<SSHNP>>> {
//   final Ref ref;

//   HomeScreenController({required this.ref}) : super(const AsyncValue.loading());

//   /// Get list of [AtData] associated with the current astign.
//   Future<void> getConfigFiles() async {
//     state = const AsyncValue.loading();
//     state = await AsyncValue.guard(() async {
//       try {
//         final sshnpParms = await SSHNPParams.getConfigFilesFromDirectory();
//         final sshnpList = await Future.wait(sshnpParms
//             .map((e) => SSHNP.fromParams(
//                   e,
//                   // atClient: AtClientManager.getInstance().atClient,
//                 ))
//             .toList());
//         return sshnpList;
//       } on PathNotFoundException {
//         log('Path Not Found');
//         return [];
//       }
//     });
//   }

//   /// Deletes the [AtKey] associated with the [AtData].
//   Future<bool> delete(AtData atData) async {
//     state = const AsyncValue.loading();
//     final directory = getDefaultSshnpConfigDirectory(getHomeDirectory()!);
//     var files = Directory(directory).list().firstWhere((element) => element.path.contains(atData.atKey.toString()));
//     await getConfigFiles();

//     return result;
//   }

//   /// Deletes all [AtData] associated with the current atsign.
//   Future<void> deleteAllData() async {
//     state = const AsyncValue.loading();
//     await ref.watch(dataRepositoryProvider).deleteAllData();
//     state = await AsyncValue.guard(() async => await ref.watch(dataRepositoryProvider).getData());
//   }
// }

// /// A provider that exposes the [HomeScreenController] to the app.
// final atDataControllerProvider =
//     StateNotifierProvider<HomeScreenController, AsyncValue<List<SSHNP>>>((ref) => HomeScreenController(ref: ref));
