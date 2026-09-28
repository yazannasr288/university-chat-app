import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_empty_state.dart';
import 'app_loader.dart';

class AppStateView extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool empty;
  final Widget child;
  final String emptyText;
  final String? errorText;
  final IconData emptyIcon;
  final IconData errorIcon;
  final VoidCallback? onRetry;
  final Widget? loadingWidget;

  const AppStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.child,
    required this.emptyText,
    this.errorText,
    this.emptyIcon = Icons.inbox_rounded,
    this.errorIcon = Icons.error_outline_rounded,
    this.onRetry,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    late final Widget content;
    late final String stateKey;

    if (loading) {
      content = loadingWidget ?? const AppLoader();
      stateKey = 'loading';
    } else {
      final cleanError = error?.trim() ?? '';
      if (cleanError.isNotEmpty) {
        content = AppEmptyState(
          icon: errorIcon,
          text: errorText ?? cleanError,
          actionLabel: onRetry == null ? null : tr('common.retry'),
          onAction: onRetry,
        );
        stateKey = 'error';
      } else if (empty) {
        content = AppEmptyState(
          icon: emptyIcon,
          text: emptyText,
          actionLabel: onRetry == null ? null : tr('common.retry'),
          onAction: onRetry,
        );
        stateKey = 'empty';
      } else {
        content = child;
        stateKey = 'content';
      }
    }

    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.medium),
      reverseDuration: AppMotion.resolve(context, AppMotion.fast),
      switchInCurve: AppMotion.standard,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (transitionChild, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
            child: transitionChild,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<String>(stateKey), child: content),
    );
  }
}
