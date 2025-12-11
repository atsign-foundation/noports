import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

import '../../../util/form_validator.dart';
import '../../policy/models/policy.dart';

class DeviceGroupListWidget extends StatefulWidget {
  final String label;
  final List<DeviceGroup> deviceGroups;
  final bool isEditing;
  final Function(List<DeviceGroup>) onChanged;
  final String? helperText;
  final String? tooltip;

  const DeviceGroupListWidget({
    super.key,
    required this.label,
    required this.deviceGroups,
    required this.isEditing,
    required this.onChanged,
    this.helperText,
    this.tooltip,
  });

  @override
  State<DeviceGroupListWidget> createState() => _DeviceGroupListWidgetState();
}

class _DeviceGroupListWidgetState extends State<DeviceGroupListWidget> {
  late List<DeviceGroup> _localDeviceGroups;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _localDeviceGroups = List.from(widget.deviceGroups);
  }

  @override
  void didUpdateWidget(DeviceGroupListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceGroups != widget.deviceGroups) {
      _localDeviceGroups = List.from(widget.deviceGroups);
    }
  }

  void _addDeviceGroup() {
    showDialog(
      context: context,
      builder: (context) => _AddDeviceGroupDialog(
        onAdd: (deviceGroup) {
          setState(() {
            _localDeviceGroups.add(deviceGroup);
          });
          widget.onChanged(_localDeviceGroups);
        },
      ),
    );
  }

  void _editDeviceGroup(int index) {
    showDialog(
      context: context,
      builder: (context) => _AddDeviceGroupDialog(
        deviceGroup: _localDeviceGroups[index],
        onAdd: (deviceGroup) {
          setState(() {
            _localDeviceGroups[index] = deviceGroup;
          });
          widget.onChanged(_localDeviceGroups);
        },
      ),
    );
  }

  void _removeDeviceGroup(int index) {
    setState(() {
      _localDeviceGroups.removeAt(index);
    });
    widget.onChanged(_localDeviceGroups);
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

        if (_localDeviceGroups.isEmpty)
          Container(
            padding: const EdgeInsets.all(Sizes.p16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(Sizes.p4),
              color: Colors.grey[50],
            ),
            child: Center(
              child: Text(
                strings.deviceGroupsNotAdded,
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(Sizes.p4),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localDeviceGroups.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: Sizes.p1),
              itemBuilder: (context, index) {
                final deviceGroup = _localDeviceGroups[index];
                return ListTile(
                  dense: false,
                  leading: const Icon(Icons.group_work, size: 24),
                  title: Text(deviceGroup.name),
                  subtitle: deviceGroup.permitOpens.isNotEmpty
                      ? Text(
                          strings.permitOpens(
                            deviceGroup.permitOpens.join(', '),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        )
                      : Text(
                          strings.permitOpensNotConfigured,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                  trailing: widget.isEditing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.black),
                              onPressed: () => _editDeviceGroup(index),
                              iconSize: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeDeviceGroup(index),
                              iconSize: 20,
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),

        if (widget.isEditing) ...[
          const SizedBox(height: Sizes.p12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addDeviceGroup,
              icon: const Icon(Icons.add, size: Sizes.p18),
              label: Text(strings.groupAdd),
              style: ElevatedButton.styleFrom(alignment: Alignment.center),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddDeviceGroupDialog extends StatefulWidget {
  final DeviceGroup? deviceGroup;
  final Function(DeviceGroup) onAdd;

  const _AddDeviceGroupDialog({this.deviceGroup, required this.onAdd});

  @override
  State<_AddDeviceGroupDialog> createState() => _AddDeviceGroupDialogState();
}

class _AddDeviceGroupDialogState extends State<_AddDeviceGroupDialog> {
  late TextEditingController _nameController;
  late TextEditingController _permitOpenController;
  late List<String> _permitOpens;

  final _deviceGroupFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.deviceGroup?.name ?? '',
    );
    _permitOpenController = TextEditingController();
    _permitOpens = List.from(widget.deviceGroup?.permitOpens ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _permitOpenController.dispose();
    super.dispose();
  }

  void _addPermitOpen() {
    if (!_deviceGroupFormKey.currentState!.validate()) return;
    final value = _permitOpenController.text.trim();

    // final validationError = FormValidator.validateHostPortField(value);
    // if (validationError != null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(validationError), backgroundColor: Colors.red),
    //   );
    //   return;
    // }

    if (value.isNotEmpty && !_permitOpens.contains(value)) {
      setState(() {
        _permitOpens.add(value);
        _permitOpenController.clear();
      });
    }
  }

  void _removePermitOpen(String value) {
    setState(() {
      _permitOpens.remove(value);
    });
  }

  void _save() {
    // if (!_deviceGroupFormKey.currentState!.validate()) return;
    if (_nameController.text.trim().isNotEmpty) {
      final deviceGroup = DeviceGroup(
        name: _nameController.text.trim(),
        permitOpens: _permitOpens,
      );
      widget.onAdd(deviceGroup);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.deviceGroup == null
            ? strings.deviceGroupAdd
            : strings.deviceGroupEdit,
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: Sizes.p400,
          child: Form(
            key: _deviceGroupFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: Sizes.p90,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: strings.groupName,
                      border: const OutlineInputBorder(),
                      errorMaxLines: 2,
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormValidator.validateRequiredField,
                  ),
                ),
                const SizedBox(height: Sizes.p16),

                Text(
                  strings.permitOpensHostPort,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: Sizes.p8),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: Sizes.p90,
                        child: TextFormField(
                          controller: _permitOpenController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            errorMaxLines: 2,
                          ),
                          // onSubmitted: (_) => _addPermitOpen(),
                          autovalidateMode: _permitOpens.isEmpty
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          validator: FormValidator.validateHostPortField,
                        ),
                      ),
                    ),
                    gapW8,
                    ElevatedButton(
                      onPressed: _addPermitOpen,

                      child: Text(strings.add),
                    ),
                  ],
                ),
                const SizedBox(height: Sizes.p8),

                if (_permitOpens.isNotEmpty)
                  Container(
                    height: Sizes.p150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(Sizes.p4),
                    ),
                    child: ListView.builder(
                      itemCount: _permitOpens.length,
                      itemBuilder: (context, index) {
                        final permitOpen = _permitOpens[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.link, size: Sizes.p16),
                          title: Text(permitOpen),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _removePermitOpen(permitOpen),
                            iconSize: Sizes.p16,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: _permitOpens.isNotEmpty ? _save : null,
          child: Text(strings.save),
        ),
      ],
    );
  }
}
