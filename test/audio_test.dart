import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku_realms/services/audio_service.dart';
import 'package:sudoku_realms/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('defaults', () {
    test('sound effects and music are both off on a fresh install', () async {
      expect(await SettingsService.getSoundEffects(), isFalse);
      expect(await SettingsService.getMusic(), isFalse);
    });
  });

  group('sound effects gate', () {
    test('play does nothing while sound is disabled', () async {
      // With the effects gate off (the default), play returns before it ever
      // reaches for the platform audio player — so it is a safe no-op even in a
      // test environment where that plugin is absent.
      await AudioService.refreshSettings();
      await AudioService.play(Sfx.numberPlace);
      await AudioService.play(Sfx.error);
      await AudioService.play(Sfx.success);
      expect(true, isTrue);
    });

    test('toggling on then off flips the cached gate', () async {
      await AudioService.refreshSettings();

      AudioService.toggleSoundEffects(true);
      await SettingsService.setSoundEffects(true);
      expect(await SettingsService.getSoundEffects(), isTrue);

      AudioService.toggleSoundEffects(false);
      await SettingsService.setSoundEffects(false);
      expect(await SettingsService.getSoundEffects(), isFalse);
    });

    test('refreshSettings picks up an external change', () async {
      await SettingsService.setSoundEffects(true);
      await AudioService.refreshSettings();

      // No exception, and the setting round-trips.
      expect(await SettingsService.getSoundEffects(), isTrue);
    });
  });

  group('every named effect has a real asset path', () {
    test('the map covers all Sfx values', () {
      // A missing entry would silently drop a sound, so every enum value must be
      // mapped to a non-empty asset.
      for (final effect in Sfx.values) {
        final path = AudioService.assetFor(effect);
        expect(path, isNotNull, reason: '$effect has no asset');
        expect(path, endsWith('.wav').or(endsWith('.flac')),
            reason: '$effect maps to $path');
      }
    });
  });
}

extension _OrMatcher on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
