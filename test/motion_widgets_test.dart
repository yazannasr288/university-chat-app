import 'package:alwatanyachat/core/theme/app_theme.dart';
import 'package:alwatanyachat/core/widgets/app_motion_widgets.dart';
import 'package:alwatanyachat/core/widgets/app_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page entrance settles without changing its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppPageEntrance(child: Text('content'))),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    await tester.pumpAndSettle();

    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 1);
  });

  testWidgets('interactive surfaces provide press feedback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: AppSurface.card(onTap: () {}, child: const Text('press')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('press')),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.985,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('page entrance follows the reduced-motion preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AppPageEntrance(child: Text('reduced motion')),
          ),
        ),
      ),
    );

    expect(find.text('reduced motion'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });
}
