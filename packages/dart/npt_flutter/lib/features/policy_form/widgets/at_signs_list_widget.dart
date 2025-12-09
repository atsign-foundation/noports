import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

class AtSignsListWidget extends StatefulWidget {
  final String label;
  final List<String> atSigns;
  final bool isEditing;
  final Function(List<String>) onChanged;
  final String? helperText;
  final String? tooltip;
  final int maxVisibleItems;

  const AtSignsListWidget({
    super.key,
    required this.label,
    required this.atSigns,
    required this.isEditing,
    required this.onChanged,
    this.helperText,
    this.tooltip,
    this.maxVisibleItems = 5,
  });

  @override
  State<AtSignsListWidget> createState() => _AtSignsListWidgetState();
}

class _AtSignsListWidgetState extends State<AtSignsListWidget> {
  late TextEditingController _addController;
  late List<String> _localAtSigns;
  bool _isHovering = false;
  static const double _itemHeight = Sizes.p42;

  double get _listHeight {
    final itemCount = _localAtSigns.length;
    final heightForItems = itemCount <= widget.maxVisibleItems
        ? itemCount * _itemHeight
        : widget.maxVisibleItems * _itemHeight;
    return heightForItems;
  }

  @override
  void initState() {
    super.initState();
    _addController = TextEditingController();
    _localAtSigns = List.from(widget.atSigns);
  }

  @override
  void didUpdateWidget(AtSignsListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atSigns != widget.atSigns) {
      _localAtSigns = List.from(widget.atSigns);
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addAtSign() {
    final input = _addController.text.trim();
    if (input.isEmpty) return;

    final newAtSign = input.startsWith('@') ? input : '@$input';

    if (!_localAtSigns.contains(newAtSign)) {
      setState(() {
        _localAtSigns.add(newAtSign);
        _addController.clear();
      });
      widget.onChanged(_localAtSigns);
    }
  }

  void _removeAtSign(String atSign) {
    setState(() {
      _localAtSigns.remove(atSign);
    });
    widget.onChanged(_localAtSigns);
  }

  void _showTooltipModal(AppLocalizations strings) {
    if (widget.tooltip == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.label),
          content: Text(widget.tooltip!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: Sizes.p16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.tooltip != null) ...[
              const SizedBox(width: Sizes.p8),
              MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                child: GestureDetector(
                  onTap: () => _showTooltipModal(strings),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Sizes.p12),
                      boxShadow: _isHovering
                          ? [
                              BoxShadow(
                                color: AppColor.primaryColor.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: Sizes.p8,
                                spreadRadius: Sizes.p2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.help_outline,
                      size: Sizes.p16,
                      color: _isHovering ? AppColor.primaryColor : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Sizes.p12),

        if (_localAtSigns.isEmpty)
          Container(
            padding: const EdgeInsets.all(Sizes.p16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(Sizes.p4),
              color: Colors.grey[50],
            ),
            child: Center(
              child: Text(
                strings.noAtsignsAdded,
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          Container(
            height: _listHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(Sizes.p4),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _localAtSigns.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: Sizes.p1, color: AppColor.dividerColor),
              itemBuilder: (context, index) {
                final atSign = _localAtSigns[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person, size: Sizes.p20),
                  title: Text(atSign),
                  trailing: widget.isEditing
                      ? IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeAtSign(atSign),
                          iconSize: Sizes.p20,
                        )
                      : null,
                );
              },
            ),
          ),

        if (widget.isEditing) ...[
          const SizedBox(height: Sizes.p12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Sizes.p12,
                      vertical: Sizes.p8,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _addAtSign(),
                ),
              ),
              gapW8,
              ElevatedButton.icon(
                onPressed: _addController.text.trim().isEmpty
                    ? null
                    : _addAtSign,
                icon: const Icon(Icons.add, size: Sizes.p18),
                label: Text(strings.add),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
