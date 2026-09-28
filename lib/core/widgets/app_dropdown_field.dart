import 'package:flutter/material.dart';

class AppDropdownOption<T> {
  final T value;
  final String label;

  const AppDropdownOption({
    required this.value,
    required this.label,
  });
}

class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final T? fallbackValue;
  final String label;
  final IconData? icon;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool isExpanded;

  const AppDropdownField({
    super.key,
    required this.value,
    this.fallbackValue,
    required this.label,
    this.icon,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.isExpanded = true,
  });

  T? get _effectiveValue {
    final values = options.map((option) => option.value).toList();
    if (value != null && values.contains(value)) return value;
    if (fallbackValue != null && values.contains(fallbackValue)) {
      return fallbackValue;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: _effectiveValue,
      isExpanded: isExpanded,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      selectedItemBuilder: (context) {
        return options.map((option) {
          return Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }).toList();
      },
      items: options.map((option) {
        return DropdownMenuItem<T>(
          value: option.value,
          child: Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
