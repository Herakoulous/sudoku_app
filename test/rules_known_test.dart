import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/services/save_service.dart';

/// The rules card should stop opening itself once a realm's rules are known —
/// which happens the first time a puzzle in that realm is finished.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh realm has unknown rules', () async {
    expect(await SaveService.areRulesKnown('Classic Kingdom'), isFalse);
  });

  test('marking a realm known sticks, per realm', () async {
    await SaveService.markRulesKnown('Kropki Coast');

    expect(await SaveService.areRulesKnown('Kropki Coast'), isTrue);
    // Other realms are unaffected.
    expect(await SaveService.areRulesKnown('Classic Kingdom'), isFalse);
  });
}
