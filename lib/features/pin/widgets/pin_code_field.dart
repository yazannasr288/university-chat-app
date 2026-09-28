import 'package:flutter/material.dart';

import '../../../core/widgets/app_text_field.dart';

class PinCodeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const PinCodeField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      icon: icon,
      keyboardType: TextInputType.number,
      obscureText: true,
    );
  }
}
