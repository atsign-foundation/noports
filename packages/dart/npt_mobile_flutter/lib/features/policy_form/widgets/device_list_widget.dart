import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/app_color.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';

import '../../../util/form_validator.dart';
import '../../policy/models/policy.dart';

class DeviceListWidget extends StatefulWidget {
  final String label;
  final List<Device> devices;
  final bool isEditing;
  final Function(List<Device>) onChanged;
  final String? helperText;
  final String? tooltip;

  const DeviceListWidget({
    super.key,
    required this.label,
    required this.devices,
    required this.isEditing,
    required this.onChanged,
    this.helperText,
    this.tooltip,
  });

  @override
  State<DeviceListWidget> createState() => _DeviceListWidgetState();
}

class _DeviceListWidgetState extends State<DeviceListWidget> {
  late List<Device> _localDevices;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _localDevices = List.from(widget.devices);
  }

  @override
  void didUpdateWidget(DeviceListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.devices != widget.devices) {
      _localDevices = List.from(widget.devices);
    }
  }

  void _addDevice() {
    showDialog(
      context: context,
      builder: (context) => _AddDeviceDialog(
        onAdd: (device) {
          setState(() {
            _localDevices.add(device);
          });
          widget.onChanged(_localDevices);
        },
      ),
    );
  }

  void _editDevice(int index) {
    showDialog(
      context: context,
      builder: (context) => _AddDeviceDialog(
        device: _localDevices[index],
        onAdd: (device) {
          setState(() {
            _localDevices[index] = device;
          });
          widget.onChanged(_localDevices);
        },
      ),
    );
  }

  void _removeDevice(int index) {
    setState(() {
      _localDevices.removeAt(index);
    });
    widget.onChanged(_localDevices);
  }

  void _showTooltipModal() {
    if (widget.tooltip == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final strings = AppLocalizations.of(context)!;
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
                  onTap: _showTooltipModal,
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

        if (_localDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(Sizes.p16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(Sizes.p4),
              color: Colors.grey[50],
            ),
            child: Center(
              child: Text(
                strings.devicesNotAdded,
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
              itemCount: _localDevices.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: Sizes.p1),
              itemBuilder: (context, index) {
                final device = _localDevices[index];
                return ListTile(
                  dense: false,
                  leading: const Icon(Icons.devices, size: Sizes.p24),
                  title: Text(device.name),
                  subtitle: device.permitOpens.isNotEmpty
                      ? Text(
                          strings.permitOpens(device.permitOpens.join(', ')),
                          style: TextStyle(
                            fontSize: Sizes.p12,
                            color: Colors.grey[600],
                          ),
                        )
                      : Text(
                          strings.permitOpensNotConfigured,
                          style: const TextStyle(
                            fontSize: Sizes.p12,
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
                              onPressed: () => _editDevice(index),
                              iconSize: Sizes.p20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeDevice(index),
                              iconSize: Sizes.p20,
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
              onPressed: _addDevice,
              icon: const Icon(Icons.add, size: Sizes.p18),
              label: Text(strings.deviceAdd),
              style: ElevatedButton.styleFrom(alignment: Alignment.center),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddDeviceDialog extends StatefulWidget {
  final Device? device;
  final Function(Device) onAdd;

  const _AddDeviceDialog({this.device, required this.onAdd});

  @override
  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog> {
  late TextEditingController _nameController;
  late TextEditingController _permitOpenController;
  late List<String> _permitOpens;
  final _deviceFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device?.name ?? '');
    _permitOpenController = TextEditingController();
    _permitOpens = List.from(widget.device?.permitOpens ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _permitOpenController.dispose();
    super.dispose();
  }

  void _addPermitOpen() {
    if (!_deviceFormKey.currentState!.validate()) return;

    final value = _permitOpenController.text.trim();

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
    if (_nameController.text.trim().isNotEmpty) {
      final device = Device(
        name: _nameController.text.trim(),
        permitOpens: _permitOpens,
      );
      widget.onAdd(device);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.device == null ? strings.deviceAdd : strings.deviceEdit,
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: Sizes.p400,
          child: Form(
            key: _deviceFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: Sizes.p90,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: strings.deviceName,
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
                    height: 150,
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
