import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:noports_config/platform/atsigns.dart';

/// A text field for one atsign. The "@" is drawn as a fixed prefix and
/// never part of the text, so typing "@alice", "alice" or " alice" all
/// mean the same thing. [onChanged] gets the stored form ("@alice"), or
/// null when the field is empty.
class AtsignTextField extends StatefulWidget {
  const AtsignTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.label,
    this.enabled = true,
    this.autofocus = false,
    this.controller,
    this.onSubmitted,
  });

  /// The stored value, with or without its "@".
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final String? label;
  final bool enabled;
  final bool autofocus;

  /// Supplied by callers that need to read the text back (dialogs). The
  /// controller's text is the bare name, without "@".
  final TextEditingController? controller;
  final ValueChanged<String?>? onSubmitted;

  @override
  State<AtsignTextField> createState() => _AtsignTextFieldState();
}

class _AtsignTextFieldState extends State<AtsignTextField> {
  late final TextEditingController _own;
  TextEditingController get _c => widget.controller ?? _own;

  @override
  void initState() {
    super.initState();
    _own = TextEditingController(text: Atsigns.bare(widget.value ?? ''));
    if (widget.controller != null) {
      widget.controller!.text = Atsigns.bare(widget.value ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant AtsignTextField old) {
    super.didUpdateWidget(old);
    final bare = Atsigns.bare(widget.value ?? '');
    // Follow external changes (revert, import, YAML edits) but leave the
    // caret alone when the only difference is case or an "@" the user typed.
    if (bare.toLowerCase() != _c.text.toLowerCase()) {
      _c.value = TextEditingValue(
        text: bare,
        selection: TextSelection.collapsed(offset: bare.length),
      );
    }
  }

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _changed(String s) {
    // An "@" pasted or typed in the box is dropped: the prefix already
    // shows it. Same for spaces, which no atsign contains.
    final bare = Atsigns.bare(s);
    if (bare != s) {
      _c.value = TextEditingValue(
        text: bare,
        selection: TextSelection.collapsed(offset: bare.length),
      );
    }
    widget.onChanged(Atsigns.fromInput(bare));
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint == null ? null : Atsigns.bare(widget.hint!);
    return TextField(
      controller: _c,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: hint,
        prefixText: '@',
        prefixStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      onChanged: _changed,
      onSubmitted: widget.onSubmitted == null
          ? null
          : (s) => widget.onSubmitted!(Atsigns.fromInput(s)),
    );
  }
}
