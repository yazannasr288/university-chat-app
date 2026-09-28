import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

class AppShimmer extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const AppShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shimmer.fromColors(
      baseColor: context.isDark
          ? const Color(0xFF122033)
          : context.appCardColorStrong,
      highlightColor: context.isDark
          ? const Color(0xFF1A2E45)
          : context.appCardColor.withValues(alpha: 0.58),
      child: child,
    );
  }

  static Widget chatSkeleton() {
    const bubbleHeights = [56.0, 86.0, 62.0, 170.0, 58.0, 74.0, 142.0, 60.0];

    return ListView.builder(
      itemCount: bubbleHeights.length,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 110),
      itemBuilder: (context, index) {
        final isMe = index.isEven;
        final isMedia = bubbleHeights[index] > 120;
        final width = isMedia
            ? MediaQuery.sizeOf(context).width * 0.64
            : MediaQuery.sizeOf(context).width * (index % 3 == 0 ? 0.48 : 0.58);

        return Align(
          alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            width: width,
            height: bubbleHeights[index],
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isMe ? 22 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 22),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget memberSkeleton() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
        );
      },
    );
  }
}
