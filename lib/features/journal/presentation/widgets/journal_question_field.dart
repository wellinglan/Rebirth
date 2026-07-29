import 'package:flutter/material.dart';

class JournalQuestionField extends StatelessWidget {
  const JournalQuestionField({
    required this.question,
    required this.controller,
    required this.fieldKey,
    required this.onChanged,
    this.readOnly = false,
    super.key,
  });

  final String question;
  final TextEditingController controller;
  final Key fieldKey;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      minLines: 3,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: question,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: readOnly ? null : onChanged,
    );
  }
}
