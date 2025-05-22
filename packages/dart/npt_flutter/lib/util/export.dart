import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/widgets/import_type_paste_dialog.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

enum ExportableProfileFiletype {
  json("json"),
  yaml("yaml");

  final String filetype;
  const ExportableProfileFiletype(this.filetype);

  static ExportableProfileFiletype? fromExtension(String ext) =>
      switch (ext) { "json" => json, "yaml" => yaml, _ => null };

  static Iterable<String> get filetypes => ExportableProfileFiletype.values.map((e) => e.filetype);
}

class Export {
  static const profilesKey = 'profiles';
  @visibleForTesting
  static Future<File?> pickAndCreateFile(ExportableProfileFiletype filetype) async {
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
    CustomSnackBar.success(content: AppLocalizations.of(App.navState.currentContext!)!.fileSaved);
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

  static void convertExternalDataSourceToProfile({
    required ExportableProfileFiletype fileType,
    required String contents,
  }) async {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    try {
      var json = switch (fileType) {
        ExportableProfileFiletype.json => jsonDecode(contents),

        /// Should return a [YamlMap] which implements [Map]
        ExportableProfileFiletype.yaml => loadYaml(contents),
      };

      /// Type validation to ensure type safety
      if (json is! Map) {
        CustomSnackBar.error(content: strings.fileFormatInvalid);
        throw 'decoded $fileType document is not a Map';
      }
      if (json[profilesKey] is! List) {
        CustomSnackBar.error(
          content: strings.fileFormatInvalidDetails,
        );
        throw 'profiles is not a List in this document';
      }

      var profiles = (json[profilesKey] as List)
          .map((e) {
            if (e is! Map) return null;
            return Profile.fromJson(e.cast<String, dynamic>());
          })
          .where((e) => e != null)
          .cast<Profile>();
      App.navState.currentContext?.read<ProfileListBloc>().add(ProfileListAddEvent(profiles));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomSnackBar.success(content: strings.fileImported);
      });
    } catch (e) {
      CustomSnackBar.error(content: strings.profileImportFailed);
      App.log('Failed to import file: $e'.loggable);
    }
  }

  /// A function which prompts the user to select some files and imports them
  /// asynchronously
  static void importProfiles() async {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'yaml']);

      if (result == null) {
        return;
      }
      File f = File(result.files.single.path!);
      var fileType = ExportableProfileFiletype.fromExtension(
        f.path.substring(f.path.lastIndexOf('.') + 1),
      );
      var contents = await f.readAsString();

      if (fileType == null) return;

      convertExternalDataSourceToProfile(fileType: fileType, contents: contents);
    } catch (e) {
      CustomSnackBar.error(content: strings.profileImportFailed);
      App.log('Failed to import file: $e'.loggable);
    }
  }

  static void pasteProfile() async {
    final context = App.navState.currentContext!;

    final result = await showDialog<String?>(
        useRootNavigator: true, context: context, builder: (BuildContext context) => const ImportTypePasteDialog());
    if (result == null) {
      return;
    }

    // check if the first no whitespace character is a {
    // if so, assume it's a json file
    // else assume it's a yaml file
    final ExportableProfileFiletype profileFileType;
    if (result.trimLeft().startsWith('{')) {
      profileFileType = ExportableProfileFiletype.json;
    } else {
      profileFileType = ExportableProfileFiletype.yaml;
    }

    convertExternalDataSourceToProfile(fileType: profileFileType, contents: result);
  }

  /// Fetches and returns the demo profile JSON from the provided Google Drive link.
  /// Returns a Map<String, dynamic> containing the JSON content.
  static Future<String> getDemoProfile() async {
    // The Google Drive file's direct download URL
    const fileId = '1qb0YrpRaGstLSBKoLJ4wwVUIMO5zCaMq';
    const url = 'https://drive.google.com/uc?export=download&id=$fileId';

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Failed to download demo profile: HTTP ${response.statusCode}');
      }
      final content = await response.transform(utf8.decoder).join();

      return content;
    } catch (e) {
      throw Exception('Failed to fetch demo profile: $e');
    }
  }
}
