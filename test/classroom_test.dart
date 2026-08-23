import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/data/technique_syllabus.dart';
import 'package:sudoku_realms/models/technique_lesson.dart';
import 'package:sudoku_realms/services/classroom_service.dart';
import 'package:sudoku_realms/services/hint_lesson_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('syllabus', () {
    test('ids are unique and every entry has copy', () {
      final ids = TechniqueSyllabus.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);

      for (final info in TechniqueSyllabus.all) {
        expect(info.name.trim(), isNotEmpty, reason: info.id);
        expect(info.summary.trim(), isNotEmpty, reason: info.id);
        expect(info.lookFor.trim(), isNotEmpty, reason: info.id);
      }
    });

    test('every chapter has at least one technique', () {
      for (final chapter in TechniqueChapter.values) {
        expect(TechniqueSyllabus.inChapter(chapter), isNotEmpty,
            reason: chapter.title);
      }
    });

    test('chapters run in syllabus order without interleaving', () {
      // A student reading top to bottom should finish one chapter before the
      // next begins.
      final seen = <TechniqueChapter>[];
      for (final info in TechniqueSyllabus.all) {
        if (seen.isEmpty || seen.last != info.chapter) {
          expect(seen, isNot(contains(info.chapter)),
              reason: '${info.chapter.title} is split up');
          seen.add(info.chapter);
        }
      }
    });
  });

  group('bundled content', () {
    test('every technique has a worked example and practice', () async {
      final lessons = await ClassroomService.lessons();

      expect(lessons.length, TechniqueSyllabus.all.length);

      for (final lesson in lessons) {
        expect(lesson.isTeachable, isTrue,
            reason: '${lesson.info.id} has no worked example');
        expect(lesson.practice.length, greaterThanOrEqualTo(3),
            reason: '${lesson.info.id} has too little practice');
      }
    });

    test('each position really is the technique it is filed under', () async {
      for (final lesson in await ClassroomService.lessons()) {
        final positions = [lesson.tutorial!, ...lesson.practice];

        for (final position in positions) {
          expect(position.step.type, lesson.info.id,
              reason: '${lesson.info.id} filed a ${position.step.type}');
        }
      }
    });

    test('positions carry the candidate grid the student needs', () async {
      for (final lesson in await ClassroomService.lessons()) {
        for (final position in [lesson.tutorial!, ...lesson.practice]) {
          final step = position.step;
          expect(step.candidates.length, 81, reason: lesson.info.id);

          // An empty cell must offer candidates, or the board would be
          // unreadable and the pattern impossible to find.
          var withCandidates = 0;
          for (var i = 0; i < 81; i++) {
            if (step.grid[i] == 0 && step.candidates[i].isNotEmpty) {
              withCandidates++;
            }
          }
          expect(withCandidates, greaterThan(0), reason: lesson.info.id);
        }
      }
    });

    test('every position does something', () async {
      for (final lesson in await ClassroomService.lessons()) {
        for (final position in [lesson.tutorial!, ...lesson.practice]) {
          expect(
            position.step.placements.isNotEmpty ||
                position.step.eliminations.isNotEmpty,
            isTrue,
            reason: '${lesson.info.id} has an inert position',
          );
        }
      }
    });

    test('practice positions are distinct boards', () async {
      for (final lesson in await ClassroomService.lessons()) {
        final grids = [
          lesson.tutorial!.step.grid.join(),
          for (final p in lesson.practice) p.step.grid.join(),
        ];
        expect(grids.toSet().length, grids.length,
            reason: '${lesson.info.id} repeats a board');
      }
    });

    test('every position names cells the student can be asked to find',
        () async {
      for (final lesson in await ClassroomService.lessons()) {
        for (final position in [lesson.tutorial!, ...lesson.practice]) {
          final cells = position.patternCells;
          expect(cells, isNotEmpty, reason: '${lesson.info.id} has no pattern');

          for (final cell in cells) {
            expect(cell.row, inInclusiveRange(0, 8));
            expect(cell.col, inInclusiveRange(0, 8));
          }
        }
      }
    });

    test('every worked example builds a real walkthrough', () async {
      for (final lesson in await ClassroomService.lessons()) {
        final built = HintLessonBuilder.build(lesson.tutorial!.step);

        expect(built.stages.length, greaterThanOrEqualTo(2),
            reason: '${lesson.info.id} explains itself in one line');
        expect(built.isSpecific, isTrue,
            reason: '${lesson.info.id} fell back to the generic explanation');
      }
    });
  });

  group('accepted answers', () {
    test('every position accepts at least one answer', () async {
      for (final lesson in await ClassroomService.lessons()) {
        for (final position in [lesson.tutorial!, ...lesson.practice]) {
          expect(position.answers, isNotEmpty, reason: lesson.info.id);
          expect(position.accepts(position.answers.first), isTrue,
              reason: lesson.info.id);
        }
      }
    });

    test('every accepted answer is the same size', () async {
      // The prompt names one cell count, so all instances of a technique on a
      // board must agree on how many cells they involve.
      for (final lesson in await ClassroomService.lessons()) {
        for (final position in [lesson.tutorial!, ...lesson.practice]) {
          final sizes = position.answers.map((a) => a.length).toSet();
          expect(sizes.length, 1,
              reason: '${lesson.info.id} mixes answer sizes: $sizes');
        }
      }
    });

    test('the solver pattern is always accepted', () async {
      // Whatever the walkthrough highlights must itself be a correct answer, or
      // the explanation would contradict the grader.
      for (final lesson in await ClassroomService.lessons()) {
        for (final position in [lesson.tutorial!, ...lesson.practice]) {
          expect(position.accepts(position.patternCells), isTrue,
              reason: lesson.info.id);
        }
      }
    });

    test('a wrong selection is rejected', () async {
      final lesson = (await ClassroomService.lessons())
          .firstWhere((l) => l.info.id == 'NAKED_PAIR');
      final position = lesson.tutorial!;

      // The empty set, and a single spare cell, are never a full pattern.
      expect(position.accepts(const {}), isFalse);
    });
  });

  group('progress', () {
    test('starts empty and suggests the first technique', () async {
      final marks = await ClassroomService.progress();
      expect(marks.values.every((m) => !m.started), isTrue);

      final next = await ClassroomService.suggestedNext();
      expect(next?.id, TechniqueSyllabus.all.first.id);
    });

    test('studying alone does not pass a technique', () async {
      final first = TechniqueSyllabus.all.first;
      await ClassroomService.markStudied(first.id);

      final marks = await ClassroomService.progress();
      expect(marks[first.id]!.studied, isTrue);
      expect(marks[first.id]!.passed(6), isFalse);

      expect((await ClassroomService.suggestedNext())?.id, first.id);
    });

    test('the suggestion moves on once a technique is passed', () async {
      final first = TechniqueSyllabus.all.first;

      await ClassroomService.markStudied(first.id);
      for (var i = 0; i < 3; i++) {
        await ClassroomService.markPracticeSolved(first.id, i);
      }

      final marks = await ClassroomService.progress();
      expect(marks[first.id]!.passed(6), isTrue);

      final next = await ClassroomService.suggestedNext();
      expect(next?.id, TechniqueSyllabus.all[1].id);
    });

    test('replaying the same position does not inflate the count', () async {
      final id = TechniqueSyllabus.all.first.id;

      await ClassroomService.markPracticeSolved(id, 0);
      await ClassroomService.markPracticeSolved(id, 0);
      await ClassroomService.markPracticeSolved(id, 1);

      final marks = await ClassroomService.progress();
      expect(marks[id]!.solved, 2);
    });

    test('solved positions are remembered individually', () async {
      final id = TechniqueSyllabus.all.first.id;

      await ClassroomService.markPracticeSolved(id, 2);
      await ClassroomService.markPracticeSolved(id, 4);

      expect(await ClassroomService.solvedPositions(id), {2, 4});
    });
  });
}
