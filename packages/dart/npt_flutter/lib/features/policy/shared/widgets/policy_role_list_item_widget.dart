import 'package:flutter/material.dart';

class PolicyRoleListItemWidget extends StatelessWidget {
  final String name;
  final String description;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const PolicyRoleListItemWidget({
    super.key,
    required this.name,
    required this.description,
    required this.isSelected,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          description.isEmpty ? 'No description' : description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing ??
            (onDelete != null
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  )
                : null),
        onTap: onTap,
      ),
    );
  }
}