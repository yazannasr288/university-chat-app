import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppFilterChips<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double runSpacing;

  const AppFilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
    this.spacing = AppSpacing.xs,
    this.runSpacing = AppSpacing.xs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: values.map((value) {
          final isSelected = value == selected;
          return ChoiceChip(
            label: Text(labelBuilder(value)),
            selected: isSelected,
            onSelected: (_) => onChanged(value),
            labelStyle: context.textTheme.bodySmall?.copyWith(
              color: isSelected ? Colors.white : context.appTextSecondary,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: context.appPrimary,
            backgroundColor: context.appSurfaceSoft,
            side: BorderSide(
              color: isSelected
                  ? context.appPrimary.withValues(alpha: 0.35)
                  : context.appBorder,
            ),
          );
        }).toList(),
      ),
    );
  }
}
