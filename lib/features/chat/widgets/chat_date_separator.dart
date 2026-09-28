import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ChatDateSeparator extends StatelessWidget {
  final String label;

  const ChatDateSeparator({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = context.appBorder.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: context.appGlassSurface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: context.appGlassBorder),
              boxShadow: context.isDark ? const [] : AppShadows.subtle,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: lineColor)),
        ],
      ),
    );
  }
}
