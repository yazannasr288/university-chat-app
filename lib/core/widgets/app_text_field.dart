import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool enabled;
  final String? helperText;
  final int? maxLength;
  final int minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.label,
    this.readOnly = false,
    this.enabled = true,
    this.helperText,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.inputFormatters,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: readOnly,
      enabled: enabled,
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLength: maxLength,
      minLines: obscureText ? 1 : minLines,
      maxLines: obscureText ? 1 : maxLines,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: context.textTheme.bodyLarge?.copyWith(
        color: context.appTextPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        helperText: helperText,
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
