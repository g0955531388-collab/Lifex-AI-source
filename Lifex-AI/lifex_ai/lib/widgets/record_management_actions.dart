import 'package:flutter/material.dart';

/// Shared edit/delete actions for data rows, documents, timers and notes.
/// The owner supplies the actual editor and persistence callbacks.
class RecordManagementActions extends StatelessWidget {
  const RecordManagementActions({
    super.key,
    required this.onEdit,
    this.onDelete,
    this.deleteLabel = 'حذف',
    this.editLabel = 'تعديل',
    this.enabled = true,
  });

  final VoidCallback onEdit;
  final Future<void> Function()? onDelete;
  final String editLabel;
  final String deleteLabel;
  final bool enabled;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من حذف هذا العنصر؟ لن يتم الحذف قبل التأكيد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(deleteLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete?.call();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: editLabel,
            onPressed: enabled ? onEdit : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: deleteLabel,
              onPressed: enabled ? () => _confirmDelete(context) : null,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      );
}
