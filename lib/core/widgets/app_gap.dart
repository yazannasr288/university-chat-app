import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Central spacing primitive used instead of ad-hoc SizedBox values.
class AppGap extends StatelessWidget {
  final double size;
  final Axis axis;

  const AppGap(
    this.size, {
    super.key,
    this.axis = Axis.vertical,
  });

  const AppGap.xxs({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.xxs;

  const AppGap.xs({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.xs;

  const AppGap.sm({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.sm;

  const AppGap.md({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.md;

  const AppGap.lg({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.lg;

  const AppGap.xl({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.xl;

  const AppGap.xxl({super.key, this.axis = Axis.vertical})
      : size = AppSpacing.xxl;

  const AppGap.horizontal(this.size, {super.key}) : axis = Axis.horizontal;

  const AppGap.vertical(this.size, {super.key}) : axis = Axis.vertical;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: axis == Axis.horizontal ? size : null,
      height: axis == Axis.vertical ? size : null,
    );
  }
}
