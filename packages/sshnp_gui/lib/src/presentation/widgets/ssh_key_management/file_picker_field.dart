import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/file_picker_controller.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

class FilePickerField extends ConsumerStatefulWidget {
  static const defaultWidth = 192.0;
  static const defaultHeight = 33.0;
  const FilePickerField({
    super.key,
    this.initialValue,
    this.validator,
    this.width = defaultWidth,
    this.height = defaultHeight,
    required this.onTap,
    required this.fileName,
  });

  final String? initialValue;
  final double width;
  final double height;

  final String fileName;
  final void Function() onTap;
  final String? Function(String?)? validator;

  @override
  ConsumerState<FilePickerField> createState() => _FilePickerFieldState();
}

class _FilePickerFieldState extends ConsumerState<FilePickerField> {
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: ref.read(filePickerController.notifier).fileName);

    controller.addListener(
      () {
        setState(
          () {
            controller.text = ref.read(filePickerController.notifier).fileName;
          },
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
          controller: controller,
          textAlign: TextAlign.center,
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: kProfileFormFieldColor,
            border: InputBorder.none,
            hintText: AppLocalizations.of(context)!.selectPrivateKey,
            hintStyle: Theme.of(context).textTheme.bodyLarge,
          ),
          onTap: () async {
            await ref.read(filePickerController.notifier).getFileDetails();
            controller.notifyListeners();
          },

          // validator: FormValidator.validateOptio,
        ),
      ),
    );
  }
}
