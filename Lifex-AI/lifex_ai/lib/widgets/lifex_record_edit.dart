/// زر تعديل ظاهر على صف السجل.
library lifex_ai.widgets.lifex_record_edit;

import 'package:flutter/material.dart';

import '../core/app_config.dart';

class LifexRecordEditButton extends StatelessWidget {
  const LifexRecordEditButton({
    super.key,
    required this.onPressed,
    this.referenceOnly = false,
  });

  final VoidCallback? onPressed;

  /// مرجع عام: الزر يظهر ويوضح أن النص لا يُستبدل كحقيقة.
  final bool referenceOnly;

  @override
  Widget build(BuildContext context) {
    final label = lifexUi('تعديل', 'Edit');
    return Semantics(
      button: true,
      label: referenceOnly
          ? lifexUi(
              'تعديل. هذا مرجع عام وليس سجلاً شخصياً',
              'Edit. This is general reference, not a personal record',
            )
          : label,
      child: IconButton(
        tooltip: label,
        onPressed: referenceOnly
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lifexUi(
                      'هذا مرجع عام. التعديل للسجل الشخصي فقط، وبلا تغيير لجرعة.',
                      'This is general reference. Edit applies to your own record only, and does not change a dose.',
                    )),
                  ),
                );
              }
            : onPressed,
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

Future<String?> lifexEditText(
  BuildContext context, {
  required String titleAr,
  required String titleEn,
  required String labelAr,
  required String labelEn,
  required String initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextEditDialog(
      titleAr: titleAr,
      titleEn: titleEn,
      labelAr: labelAr,
      labelEn: labelEn,
      initial: initial,
    ),
  );
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.titleAr,
    required this.titleEn,
    required this.labelAr,
    required this.labelEn,
    required this.initial,
  });

  final String titleAr;
  final String titleEn;
  final String labelAr;
  final String labelEn;
  final String initial;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(lifexUi(widget.titleAr, widget.titleEn)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: lifexUi(widget.labelAr, widget.labelEn),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lifexUi('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(lifexUi('حفظ', 'Save')),
        ),
      ],
    );
  }
}
