import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/constants.dart';

class PolicyLogItem extends StatefulWidget {
  final String timestamp;
  final Atsign? fromAtsign;
  final Atsign? toAtsign;
  final String type;
  final String deviceName;
  final String deviceGroup;
  final String allowedServices;
  final String? policyPayload;

  const PolicyLogItem({
    super.key,
    required this.timestamp,
    required this.fromAtsign,
    required this.toAtsign,
    required this.type,
    required this.deviceName,
    required this.deviceGroup,
    required this.allowedServices,
    this.policyPayload,
  });

  @override
  State<PolicyLogItem> createState() => _PolicyLogItemState();
}

class _PolicyLogItemState extends State<PolicyLogItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: widget.timestamp,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.timestamp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: StringConst.monospace,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: widget.fromAtsign,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.fromAtsign ?? 'unknown',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: widget.toAtsign,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.toAtsign ?? 'unknown',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Tooltip(
                    message: widget.type,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(widget.type),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.type,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Tooltip(
                    message: widget.deviceName,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.deviceName,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Tooltip(
                    message: widget.deviceGroup.isEmpty
                        ? strings.deviceGroupNo
                        : widget.deviceGroup,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.deviceGroup.isEmpty ? '-' : widget.deviceGroup,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.deviceGroup.isEmpty ? Colors.grey : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: widget.allowedServices,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.allowedServices,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (widget.type == 'policy request' &&
                    widget.policyPayload != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    iconSize: 20,
                  ),
                ],
              ],
            ),
          ),
          if (_isExpanded &&
              widget.type == 'policy request' &&
              widget.policyPayload != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.code,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.policyRequestPayload,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w300,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.policyPayload!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.jsonPayloadCopiedToClipboard,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: strings.jsonCopyToClipboard,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _formatJson(widget.policyPayload!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: StringConst.monospace,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatJson(String jsonString) {
    try {
      final dynamic jsonData = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonData);
    } catch (e) {
      return jsonString;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'heartbeat':
        return Colors.green;
      case 'connection':
        return Colors.blue;
      case 'authentication':
        return Colors.purple;
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.grey;
      case 'policy request':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }
}
