import 'package:flutter/material.dart';

import 'app_radii.dart';

abstract final class AppDecorations {
  static BorderRadius radius([double value = AppRadii.lg]) =>
      BorderRadius.circular(value);

  static BorderRadius get pillRadius => BorderRadius.circular(AppRadii.pill);

  static BoxDecoration surface({
    required Color color,
    Color? borderColor,
    double borderWidth = 1,
    Gradient? gradient,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: borderRadius ?? radius(AppRadii.xl),
      border: borderColor == null
          ? null
          : Border.all(color: borderColor, width: borderWidth),
      boxShadow: boxShadow,
    );
  }

  static BoxDecoration pill({
    required Color color,
    Color? borderColor,
    double borderWidth = 1,
    List<BoxShadow>? boxShadow,
  }) {
    return surface(
      color: color,
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderRadius: pillRadius,
      boxShadow: boxShadow,
    );
  }

  static BoxDecoration rounded({
    required Color color,
    double radius = AppRadii.md,
    Color? borderColor,
    double borderWidth = 1,
    Gradient? gradient,
    List<BoxShadow>? boxShadow,
  }) {
    return surface(
      color: color,
      borderColor: borderColor,
      borderWidth: borderWidth,
      gradient: gradient,
      borderRadius: AppDecorations.radius(radius),
      boxShadow: boxShadow,
    );
  }

  static BoxDecoration circle({
    required Color color,
    Gradient? gradient,
    Color? borderColor,
    double borderWidth = 1,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      shape: BoxShape.circle,
      border: borderColor == null
          ? null
          : Border.all(color: borderColor, width: borderWidth),
      boxShadow: boxShadow,
    );
  }
}
