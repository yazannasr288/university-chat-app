part of '../message_content.dart';

class _AudioProgressBar extends StatelessWidget {
  final double progress;
  final bool enabled;
  final Color activeColor;
  final Color trackColor;
  final ValueChanged<double> onSeekFraction;

  const _AudioProgressBar({
    required this.progress,
    required this.enabled,
    required this.activeColor,
    required this.trackColor,
    required this.onSeekFraction,
  });

  void _seekFromGlobalPosition(BuildContext context, Offset globalPosition) {
    if (!enabled) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || renderObject.size.width <= 0) return;

    final local = renderObject.globalToLocal(globalPosition);
    final rawFraction = (local.dx / renderObject.size.width).clamp(0.0, 1.0);
    final textDirection = Directionality.of(context);
    final fraction = textDirection == ui.TextDirection.rtl
        ? 1.0 - rawFraction
        : rawFraction;

    onSeekFraction(fraction.clamp(0.0, 1.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (details) => _seekFromGlobalPosition(
                context,
                details.globalPosition,
              )
          : null,
      onHorizontalDragStart: enabled
          ? (details) => _seekFromGlobalPosition(
                context,
                details.globalPosition,
              )
          : null,
      onHorizontalDragUpdate: enabled
          ? (details) => _seekFromGlobalPosition(
                context,
                details.globalPosition,
              )
          : null,
      child: SizedBox(
        height: 20,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: SizedBox(
              height: 5,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: trackColor),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: safeProgress,
                      heightFactor: 1,
                      child: ColoredBox(color: activeColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
