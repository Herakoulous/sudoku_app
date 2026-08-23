import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/data/solver_guides.dart';
import 'package:sudoku_realms/models/guide_lesson.dart';
import 'package:sudoku_realms/services/classroom_service.dart';
import 'package:sudoku_realms/widgets/classroom_screen.dart';
import 'package:sudoku_realms/widgets/guide_screen.dart';

Future<void> _prime(WidgetTester tester) async {
  await tester.runAsync(() => ClassroomService.lessons());
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('guide content', () {
    test('every guide is complete and uniquely identified', () {
      final ids = <String>{};
      expect(SolverGuides.all, isNotEmpty);

      for (final guide in SolverGuides.all) {
        expect(guide.title.trim(), isNotEmpty);
        expect(guide.summary.trim(), isNotEmpty);
        expect(guide.blocks, isNotEmpty, reason: '${guide.id} has no content');
        expect(ids.add(guide.id), isTrue, reason: 'duplicate id ${guide.id}');
      }
    });

    test('there is a lesson about pencil-mark notation', () {
      final notation = SolverGuides.all.firstWhere(
        (g) => g.title.toLowerCase().contains('note') ||
            g.title.toLowerCase().contains('pencil'),
        orElse: () => throw StateError('no notation guide'),
      );

      // It should show the notation illustrations, not just prose.
      final hasDemo = notation.blocks.any((b) => b is GuideDemo);
      expect(hasDemo, isTrue,
          reason: 'the notation guide should illustrate the marks');
    });
  });

  group('guide progress', () {
    test('marking a guide read sticks and is per-guide', () async {
      final first = SolverGuides.all.first.id;

      expect(await ClassroomService.readGuides(), isEmpty);
      await ClassroomService.markGuideRead(first);

      final read = await ClassroomService.readGuides();
      expect(read, contains(first));
      expect(read.length, 1);
    });

    test('reset clears read guides', () async {
      await ClassroomService.markGuideRead(SolverGuides.all.first.id);
      await ClassroomService.reset();
      expect(await ClassroomService.readGuides(), isEmpty);
    });
  });

  group('guide UI', () {
    testWidgets('the classroom shows the Foundations section', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _prime(tester);
      await tester.pumpWidget(const MaterialApp(home: ClassroomScreen()));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Foundations'), findsOneWidget);
      expect(find.text(SolverGuides.all.first.title), findsOneWidget);
    });

    testWidgets('reading a guide to the end records it', (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final guide = SolverGuides.all.first;

      await tester.pumpWidget(
        MaterialApp(home: GuideScreen(guide: guide)),
      );
      await _settle(tester);

      expect(find.text(guide.title), findsOneWidget);

      await tester.tap(find.text('Mark as read'));
      await _settle(tester);

      final read = await ClassroomService.readGuides();
      expect(read, contains(guide.id));
    });
  });
}
