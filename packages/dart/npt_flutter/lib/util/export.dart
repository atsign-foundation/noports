import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:yaml_writer/yaml_writer.dart';

enum ExportableProfileFiletype {
  json("json"),
  yaml("yaml");

  final String filetype;
  const ExportableProfileFiletype(this.filetype);

  static Iterable<String> get filetypes =>
      ExportableProfileFiletype.values.map((e) => e.filetype);
}

class Export {
  static const profilesKey = 'profiles';
  @visibleForTesting
  static Future<File?> pickAndCreateFile(
      ExportableProfileFiletype filetype) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select a file to export to:',
      fileName: 'export.${filetype.filetype}',
    );

    if (outputFile == null) return null;

    var f = File(outputFile);
    await f.create(recursive: true);
    return f;
  }

  @visibleForTesting
  static saveFile(
    ExportableProfileFiletype filetype,
    FutureOr<Iterable<Map<String, dynamic>>> exportableProfiles,
  ) async {
    var f = await pickAndCreateFile(filetype);
    if (f == null) return;

    /// Explicit type safety
    List exportableProfileList = (await exportableProfiles).toList();

    /// Wrapping like this allows us the ability to expand the file type spec
    /// if we need to in the future
    Map<String, List> json = {profilesKey: exportableProfileList};
    switch (filetype) {
      case ExportableProfileFiletype.json:
        f.writeAsString(jsonEncode(json));
      case ExportableProfileFiletype.yaml:
        f.writeAsString(YamlWriter().convert(json));
    }
  }

  /// A closure function which returns a void Function() that prompts the user
  /// to select a file of filetype [filetype] and exports the profiles in
  /// [exportableProfiles] asynchronously
  static void Function() getExportCallback(
    ExportableProfileFiletype filetype,
    FutureOr<Iterable<Map<String, dynamic>>> exportableProfiles,
  ) {
    return () {
      saveFile(filetype, exportableProfiles);
    };
  }

  /// A function which prompts the user to select some files and imports them
  /// asynchronously
  static void importProfiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null) {
        return;
      }
      File f = File(result.files.single.path!);

      var contents = await f.readAsString();
      var json = jsonDecode(contents);

      /// Type validation to ensure type safety
      if (json is! Map) throw 'decoded document is not a Map';
      if (json[profilesKey] is! List) {
        throw 'profiles is not a List in this document';
      }

      var profiles = (json[profilesKey] as List)
          .map((e) {
            if (e is! Map<String, dynamic>) return null;
            return Profile.fromJson(e);
          })
          .where((e) => e != null)
          .cast<Profile>();

      App.navState.currentContext
          ?.read<ProfileListBloc>()
          .add(ProfileListAddEvent(profiles));
    } catch (e) {
      App.log('Failed to import file: $e'.loggable);
    }
  }
}
