import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/main.dart';

void main() {
  setUp(() {
    // Startup reads SharedPreferences (resumable game, classroom); a mock store
    // keeps that from throwing a platform exception.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app boots into the shell on the Play tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SudokuRealmsApp());

    // Content fades in on a stagger; settle before asserting.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Play tab hero.
    expect(find.text('SUDOKU'), findsOneWidget);
    expect(find.text('REALMS'), findsOneWidget);

    // Bottom navigation is present.
    expect(find.text('Play'), findsWidgets);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
