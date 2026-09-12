import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';

/// Renders one [ConfigField] as label, help text and the right control for
/// its [FieldKind]. All edits are reported through [onChanged] with a value
/// of the field's natural Dart type.
class ConfigFieldWidget extends StatelessWidget {
  const ConfigFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.problem,
  });

  final ConfigField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final def = field.defaultValue;
    final showDefault = def != null &&
        def.toString().isNotEmpty &&
        def.toString() != '__none__' &&
        field.kind != FieldKind.boolean &&
        field.kind != FieldKind.triStateBoolean;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sizes.p12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Sizes.p280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: field.label,
                    children: [
                      if (field.required)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: AppColor.primaryColor),
                        ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                if (field.help.isNotEmpty) ...[
                  gapH4,
                  Text(
                    field.help,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.onSurfaceColor,
                    ),
                  ),
                ],
                if (showDefault) ...[
                  gapH4,
                  Text(
                    strings.defaultValueHint(def.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.onSurfaceColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          gapW24,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _control(context),
                if (problem != null) ...[
                  gapH4,
                  Text(
                    problem!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.errorColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _control(BuildContext context) {
    final strings = AppLocalizations.of(context);
    switch (field.kind) {
      case FieldKind.text:
      case FieldKind.atsign:
        return SyncedTextField(
          value: value?.toString() ?? '',
          hint: field.placeholder,
          onChanged: (s) => onChanged(s),
        );
      case FieldKind.password:
        return SyncedTextField(
          value: value?.toString() ?? '',
          obscure: true,
          onChanged: (s) => onChanged(s),
        );
      case FieldKind.integer:
        return SizedBox(
          width: 160,
          child: SyncedTextField(
            value: value?.toString() ?? '',
            hint: field.placeholder,
            keyboardType: TextInputType.number,
            onChanged: (s) {
              final n = int.tryParse(s.trim());
              onChanged(s.trim().isEmpty ? null : (n ?? s));
            },
          ),
        );
      case FieldKind.filePath:
      case FieldKind.dirPath:
        return Row(
          children: [
            Expanded(
              child: SyncedTextField(
                value: value?.toString() ?? '',
                hint: field.placeholder,
                onChanged: (s) => onChanged(s),
              ),
            ),
            gapW8,
            OutlinedButton(
              onPressed: () async {
                String? picked;
                if (field.kind == FieldKind.dirPath) {
                  picked = await FilePicker.getDirectoryPath();
                } else {
                  final r = await FilePicker.pickFiles();
                  picked = r?.files.single.path;
                }
                if (picked != null) onChanged(picked);
              },
              child: Text(strings.browse),
            ),
          ],
        );
      case FieldKind.boolean:
        final b = value is bool ? value as bool : (field.defaultValue as bool? ?? false);
        return Align(
          alignment: Alignment.centerLeft,
          child: Switch(value: b, onChanged: onChanged),
        );
      case FieldKind.triStateBoolean:
        return SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: value == null ? 'default' : (value == true ? 'on' : 'off'),
            items: [
              DropdownMenuItem(value: 'default', child: Text(strings.defaultLabel)),
              DropdownMenuItem(value: 'on', child: Text(strings.onLabel)),
              DropdownMenuItem(value: 'off', child: Text(strings.offLabel)),
            ],
            onChanged: (v) => onChanged(switch (v) {
              'on' => true,
              'off' => false,
              _ => null,
            }),
          ),
        );
      case FieldKind.choice:
        final current = value?.toString();
        return SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            initialValue: field.choices.contains(current) ? current : null,
            hint: Text(strings.defaultLabel),
            items: [
              for (final c in field.choices)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: onChanged,
          ),
        );
      case FieldKind.stringList:
      case FieldKind.atsignList:
        final items = value is List
            ? (value as List).map((e) => e.toString()).toList()
            : value is String && (value as String).isNotEmpty
            ? [value as String]
            : <String>[];
        return StringListField(
          items: items,
          hint: field.placeholder,
          onChanged: onChanged,
        );
    }
  }
}

/// A TextField that follows an external value (so Revert and YAML edits
/// show up) without fighting the user's caret while typing.
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant SyncedTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      autofocus: widget.autofocus,
      decoration: InputDecoration(hintText: widget.hint),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

/// Chips for existing entries plus a text box and Add button.
class StringListField extends StatefulWidget {
  const StringListField({
    super.key,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String? hint;

  @override
  State<StringListField> createState() => _StringListFieldState();
}

class _StringListFieldState extends State<StringListField> {
  final _c = TextEditingController();

  void _add() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    if (!widget.items.contains(v)) widget.onChanged([...widget.items, v]);
    _c.clear();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Sizes.p8),
            child: Text(
              strings.emptyList,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColor.onSurfaceColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: Sizes.p8),
            child: Wrap(
              spacing: Sizes.p8,
              runSpacing: Sizes.p8,
              children: [
                for (final item in widget.items)
                  InputChip(
                    label: Text(item),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColor.textFieldBorderColor),
                    onDeleted: () => widget.onChanged(
                      widget.items.where((e) => e != item).toList(),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                decoration: InputDecoration(hintText: widget.hint),
                onSubmitted: (_) => _add(),
              ),
            ),
            gapW8,
            OutlinedButton(onPressed: _add, child: Text(strings.add)),
          ],
        ),
      ],
    );
  }
}
