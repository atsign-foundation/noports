import 'package:flutter/material.dart';

class PolicyListSectionWidget extends StatelessWidget {
  final String title;
  final List<String> items;
  final Function(List<String>) onChanged;
  final bool showAddButton;
  final Function(String)? onAddItem;
  final Function(int)? onRemoveItem;
  final Widget? emptyWidget;

  const PolicyListSectionWidget({
    super.key,
    required this.title,
    required this.items,
    required this.onChanged,
    this.showAddButton = true,
    this.onAddItem,
    this.onRemoveItem,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (showAddButton)
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: onAddItem != null
                        ? () => _showAddItemDialog(context, onAddItem!)
                        : () => _showAddItemDialog(context, (value) {
                            final newItems = [...items, value];
                            onChanged(newItems);
                          }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: items.isEmpty
                ? emptyWidget ??
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No items added',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                : ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return PolicyListItemWidget(
                        text: items[index],
                        onDelete: onRemoveItem != null
                            ? () => onRemoveItem!(index)
                            : () => _removeItemFromList(index, items, onChanged),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(
    BuildContext context,
    Function(String) onAddItem,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String itemValue = '';
        return AlertDialog(
          title: const Text('Add Item'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => itemValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (itemValue.trim().isNotEmpty) {
                  onAddItem(itemValue.trim());
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeItemFromList(
    int index,
    List<String> items,
    Function(List<String>) onChanged,
  ) {
    final newItems = [...items];
    newItems.removeAt(index);
    onChanged(newItems);
  }
}

class PolicyListItemWidget extends StatelessWidget {
  final String text;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool dense;

  const PolicyListItemWidget({
    super.key,
    required this.text,
    this.onDelete,
    this.onTap,
    this.leading,
    this.trailing,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        dense: dense,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: leading,
        title: Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: trailing ??
            (onDelete != null
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null),
        onTap: onTap,
      ),
    );
  }
}