import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_realms/services/achievement_service.dart';
import 'package:sudoku_realms/widgets/achievement_notification.dart';

void main() {
  tearDown(AchievementNotification.resetForTesting);

  testWidgets('a banner appears and names the award', (tester) async {
    final award = AchievementService.byId('first_solve')!;

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    AchievementNotification.show(ctx, award);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(award.name), findsOneWidget);
    expect(find.text(award.description), findsOneWidget);
    expect(find.textContaining('UNLOCKED'), findsOneWidget);

    // Let it retire so the static queue does not leak into the next test.
    await tester.pump(AchievementNotification.visibleDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('the banner stays up long enough to read', (tester) async {
    final award = AchievementService.byId('first_solve')!;

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    // Four seconds was the old duration and it was too brief to catch while a
    // completion dialog was animating in.
    expect(
      AchievementNotification.visibleDuration.inSeconds,
      greaterThanOrEqualTo(5),
    );

    AchievementNotification.show(ctx, award);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Still on screen most of the way through the window.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text(award.name), findsOneWidget);

    await tester.pump(AchievementNotification.visibleDuration);
    await tester.pumpAndSettle();

    expect(find.text(award.name), findsNothing);
  });

  testWidgets('several awards queue instead of stacking', (tester) async {
    final first = AchievementService.byId('first_solve')!;
    final second = AchievementService.byId('solve_5')!;

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    AchievementNotification.showAll(ctx, [first, second]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Only one banner at a time — two overlapping cards would be unreadable.
    expect(find.text(first.name), findsOneWidget);
    expect(find.text(second.name), findsNothing);

    await tester.pump(AchievementNotification.visibleDuration);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(first.name), findsNothing);
    expect(find.text(second.name), findsOneWidget);

    await tester.pump(AchievementNotification.visibleDuration);
    await tester.pumpAndSettle();

    expect(find.text(second.name), findsNothing);
  });

  testWidgets('tapping dismisses it early', (tester) async {
    final award = AchievementService.byId('first_solve')!;

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    AchievementNotification.show(ctx, award);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(award.name));
    await tester.pumpAndSettle();

    expect(find.text(award.name), findsNothing);
  });

  testWidgets('an empty list does nothing', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    AchievementNotification.showAll(ctx, const []);
    await tester.pump();

    expect(find.textContaining('UNLOCKED'), findsNothing);
  });

  testWidgets('a banner shown after a dialog sits above its barrier',
      (tester) async {
    final award = AchievementService.byId('first_solve')!;

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    // Same order as the completion flow: dialog first, banner after.
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(title: Text('Solved')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Solved'), findsOneWidget);

    AchievementNotification.show(ctx, award);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(award.name), findsOneWidget);

    // Tapping it must reach the banner, not the modal barrier underneath. If
    // the barrier were on top this tap would be swallowed and the banner would
    // still be there afterwards.
    await tester.tap(find.text(award.name));
    await tester.pumpAndSettle();

    expect(find.text(award.name), findsNothing);
    expect(find.text('Solved'), findsOneWidget);
  });
}
