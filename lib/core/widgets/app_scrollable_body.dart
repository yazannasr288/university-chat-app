import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppScrollableBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final AlignmentGeometry alignment;
  final bool keyboardDismissOnDrag;
  final ScrollPhysics? physics;

  const AppScrollableBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.maxWidth = 720,
    this.alignment = Alignment.topCenter,
    this.keyboardDismissOnDrag = true,
    this.physics,
  });

  factory AppScrollableBody.column({
    Key? key,
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
    double maxWidth = 720,
    AlignmentGeometry alignment = Alignment.topCenter,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.stretch,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    bool keyboardDismissOnDrag = true,
    ScrollPhysics? physics,
  }) {
    return AppScrollableBody(
      key: key,
      padding: padding,
      maxWidth: maxWidth,
      alignment: alignment,
      keyboardDismissOnDrag: keyboardDismissOnDrag,
      physics: physics,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: keyboardDismissOnDrag
          ? ScrollViewKeyboardDismissBehavior.onDrag
          : ScrollViewKeyboardDismissBehavior.manual,
      physics: physics,
      padding: padding,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
