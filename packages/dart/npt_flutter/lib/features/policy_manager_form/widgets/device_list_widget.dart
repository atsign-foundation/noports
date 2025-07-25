import 'package:flutter/material.dart';
import '../../policy_manager/models/policy.dart';
import '../../../util/form_validator.dart';

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
        return AlertDialog(
          title: Text(widget.label),
          content: Text(widget.tooltip!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.tooltip != null) ...[
              const SizedBox(width: 8),
              MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                child: GestureDetector(
                  onTap: _showTooltipModal,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isHovering
                          ? [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: _isHovering ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        
        // List of devices
        if (_localDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[50],
            ),
            child: const Center(
              child: Text(
                'No devices added yet',
                style: TextStyle(
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
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localDevices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = _localDevices[index];
                return ListTile(
                  dense: false,
                  leading: const Icon(Icons.devices, size: 24),
                  title: Text(device.name),
                  subtitle: device.permitOpens.isNotEmpty
                      ? Text(
                          'Permit Opens: ${device.permitOpens.join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        )
                      : const Text(
                          'No permit opens configured',
                          style: TextStyle(
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
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editDevice(index),
                              iconSize: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeDevice(index),
                              iconSize: 20,
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),
        
        // Add button below the list
        if (widget.isEditing) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addDevice,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Device'),
              style: ElevatedButton.styleFrom(
                alignment: Alignment.center,
              ),
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

  const _AddDeviceDialog({
    this.device,
    required this.onAdd,
  });

  @override
  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog> {
  late TextEditingController _nameController;
  late TextEditingController _permitOpenController;
  late List<String> _permitOpens;

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
    final value = _permitOpenController.text.trim();
    
    // Validate host:port format
    final validationError = FormValidator.validateHostPortField(value);
    if (validationError != null) {
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
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
    return AlertDialog(
      title: Text(widget.device == null ? 'Add Device' : 'Edit Device'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Permit Opens (host:port)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _permitOpenController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addPermitOpen(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addPermitOpen,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (_permitOpens.isNotEmpty)
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: _permitOpens.length,
                    itemBuilder: (context, index) {
                      final permitOpen = _permitOpens[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.link, size: 16),
                        title: Text(permitOpen),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removePermitOpen(permitOpen),
                          iconSize: 16,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}