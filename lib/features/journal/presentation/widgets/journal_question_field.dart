import 'package:flutter/material.dart';

class JournalQuestionField extends StatelessWidget {
  const JournalQuestionField({
    required this.question,
    required this.controller,
    required this.fieldKey,
    required this.onChanged,
    super.key,
  });

  final String question;
  final TextEditingController controller;
  final Key fieldKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      minLines: 3,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: question,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
