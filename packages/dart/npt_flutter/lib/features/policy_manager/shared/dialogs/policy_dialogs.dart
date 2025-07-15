import 'package:flutter/material.dart';
import '../../models/policy.dart';

class PolicyDialogs {
  PolicyDialogs._();

  /// Shows a dialog to add a new item (generic string input)
  static Future<String?> showAddItemDialog(
    BuildContext context, {
    required String title,
    required String labelText,
    String? hintText,
    bool autofocus = false,
  }) async {
    String itemValue = '';
    
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => itemValue = value,
            autofocus: autofocus,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (itemValue.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, itemValue.trim());
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a dialog to add a new role
  static Future<String?> showAddRoleDialog(BuildContext context) async {
    return showAddItemDialog(
      context,
      title: 'Add New Role',
      labelText: 'Role Name',
      hintText: 'Enter role name',
      autofocus: true,
    );
  }

  /// Shows a dialog to add a new list item
  static Future<String?> showAddListItemDialog(BuildContext context) async {
    return showAddItemDialog(
      context,
      title: 'Add Item',
      labelText: 'Value',
      hintText: 'Enter value',
    );
  }

  /// Shows a confirmation dialog for deleting a role
  static Future<bool?> showDeleteRoleDialog(
    BuildContext context,
    Role role,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${role.name}"?'),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a generic confirmation dialog
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? warningText,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (warningText != null) ...[
                const SizedBox(height: 8),
                Text(
                  warningText,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: confirmColor != null
                  ? TextButton.styleFrom(foregroundColor: confirmColor)
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}