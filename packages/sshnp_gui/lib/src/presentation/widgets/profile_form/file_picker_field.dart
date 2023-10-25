import 'dart:developer';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

import '../../../controllers/form_controllers.dart';

class FilePickerField extends ConsumerStatefulWidget {
  static const defaultWidth = 192.0;
  static const defaultHeight = 33.0;
  const FilePickerField({
    super.key,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.width = defaultWidth,
    this.height = defaultHeight,
  });

  final String? initialValue;
  final double width;
  final double height;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  @override
  ConsumerState<FilePickerField> createState() => _FilePickerFieldState();
}

class _FilePickerFieldState extends ConsumerState<FilePickerField> {
  late TextEditingController _controller;
  XFile? file;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _filePickerResult() async {
    try {
      file = await openFile(acceptedTypeGroups: <XTypeGroup>[dotPrivateTypeGroup]);
      if (file == null) return;
      _controller.text = file!.name;
    } catch (e) {}
  }

  Future<void> onSaved(String? baseFile) async {
    if (file == null) return;
    final dir = await getApplicationSupportDirectory();
    final sshDir = Directory(join(dir.path, '.ssh', ref.read(formProfileNameController).replaceAll(' ', '_')));

    final path = join(sshDir.path, file!.name);
    log(path);
    final bytes = await file!.readAsBytes();
    final targetFile = File(path);
    await targetFile.create(recursive: true);
    await targetFile.writeAsBytes(bytes);
    // await file!.saveTo(path);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      // height: height,
      child: DottedBorder(
        dashPattern: const [10, 10],
        color: kPrimaryColor,
        radius: const Radius.circular(2),
        child: TextFormField(
          controller: _controller,
          textAlign: TextAlign.center,
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: kProfileFormFieldColor,
            border: InputBorder.none,
            hintText: AppLocalizations.of(context)!.selectAFile,
            hintStyle: Theme.of(context).textTheme.bodyLarge,
          ),
          onTap: _filePickerResult,
          onSaved: onSaved,
          // validator: FormValidator.validateOptio,
        ),
      ),
    );
  }
}
