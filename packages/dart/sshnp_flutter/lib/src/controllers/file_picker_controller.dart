import 'dart:developer';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utility/constants.dart';

/// A provider that exposes the [FilePickerController] to the app.
final filePickerController =
    StateNotifierProvider<FilePickerController, AsyncValue<XFile?>>((ref) => FilePickerController(ref: ref));

/// A controller class that controls the UI update when the [FilePicker] is used.
class FilePickerController extends StateNotifier<AsyncValue<XFile?>> {
  final Ref ref;
  FilePickerController({required this.ref}) : super(const AsyncValue.loading());

  String get fileName => state.value?.name ?? '';
  Future<String> get content async => await state.value?.readAsString() ?? '';
  String get directory => state.value?.path ?? '';

  /// Get the file details.
  Future<void> getFileDetails() async {
    state = const AsyncValue.loading();
    try {
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[dotPrivateTypeGroup]);
      if (file == null) return;

      state = await AsyncValue.guard(() async => file);
    } catch (e) {
      log(e.toString());
    }
  }

  /// Clear the file details.
  /// This is used when the user wants to clear the file details.
  void clearFileDetails() {
    state = const AsyncValue.loading();
    state = const AsyncValue.data(null);
  }
}
