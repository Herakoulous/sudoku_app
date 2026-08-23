import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

/// Named sound effects. Gameplay code asks for a *meaning*, not a filename, so
/// swapping the underlying audio never means touching call sites.
enum Sfx {
  tap,
  numberPlace,
  erase,
  error,
  success,
  button,
  toggle,
  transition,
}

class AudioService {
  AudioService._();

  /// Logical sound -> asset path, relative to `assets/`.
  ///
  /// These must match real files. The previous implementation built the path as
  /// `audio/$name.mp3`, but every effect on disk is a .wav, so nothing ever
  /// played and the failures were swallowed by a catch.
  static const Map<Sfx, String> _assets = {
    Sfx.tap: 'audio/click.wav',
    Sfx.numberPlace: 'audio/319107__duffybro__pop-made-by-duffybro.wav',
    Sfx.erase: 'audio/click.wav',
    Sfx.error: 'audio/mixkit-click-error-1110.wav',
    Sfx.success: 'audio/mixkit-game-success-alert-2039.wav',
    Sfx.button: 'audio/click.wav',
    Sfx.toggle: 'audio/mixkit-on-or-off-light-switch-tap-2585.wav',
    Sfx.transition: 'audio/whoosh.flac',
  };

  /// The asset backing an effect, or null if unmapped. Exposed so tests can
  /// prove every effect resolves to a real file.
  static String? assetFor(Sfx sound) => _assets[sound];

  static const String _musicAsset = 'audio/background.mp3';

  // Players are created lazily, not on class load. Constructing an AudioPlayer
  // reaches into the platform plugin, which is absent under unit tests — so the
  // gate logic ("is sound on?") stays testable, and nothing is built until a
  // sound is genuinely about to play.
  static AudioPlayer? _musicPlayerInstance;
  static AudioPlayer get _musicPlayer =>
      _musicPlayerInstance ??= AudioPlayer();

  static List<AudioPlayer>? _sfxPoolInstance;

  /// A small pool of players. One shared effects player meant every new sound
  /// cut off the previous one, which turns fast number entry into a stutter.
  static List<AudioPlayer> get _sfxPool =>
      _sfxPoolInstance ??= List.generate(4, (_) => AudioPlayer());

  static int _nextPlayer = 0;

  static bool _isMusicPlaying = false;
  static bool _initialised = false;

  // Settings are cached because playback sits on the tap path — an async
  // SharedPreferences read per keypress is a visible hitch.
  static bool _sfxEnabled = false;
  static bool _musicEnabled = false;

  // ====================
  // INITIALISATION
  // ====================

  static Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.28);

    for (final player in _sfxPool) {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.6);
    }

    await refreshSettings();
  }

  /// Re-reads the sound settings. Call after the player changes them.
  static Future<void> refreshSettings() async {
    _sfxEnabled = await SettingsService.getSoundEffects();
    _musicEnabled = await SettingsService.getMusic();
  }

  // ====================
  // SOUND EFFECTS
  // ====================

  /// Fire-and-forget. Never awaited by gameplay code, and never throws — a
  /// missing or unsupported audio file must not interrupt a move.
  static Future<void> play(Sfx sound) async {
    if (!_sfxEnabled) return;

    final asset = _assets[sound];
    if (asset == null) return;

    try {
      final player = _sfxPool[_nextPlayer];
      _nextPlayer = (_nextPlayer + 1) % _sfxPool.length;

      await player.stop();
      await player.play(AssetSource(asset));
    } catch (e) {
      // Swallowed deliberately: audio is never worth breaking a turn over.
    }
  }

  // Convenience wrappers kept for existing call sites.
  static Future<void> playTapSound() => play(Sfx.tap);
  static Future<void> playNumberPlaceSound() => play(Sfx.numberPlace);
  static Future<void> playEraseSound() => play(Sfx.erase);
  static Future<void> playErrorSound() => play(Sfx.error);
  static Future<void> playSuccessSound() => play(Sfx.success);
  static Future<void> playButtonSound() => play(Sfx.button);
  static Future<void> playToggleSound() => play(Sfx.toggle);
  static Future<void> playTransitionSound() => play(Sfx.transition);

  // ====================
  // BACKGROUND MUSIC
  // ====================

  static Future<void> startBackgroundMusic() async {
    await initialize();
    if (!_musicEnabled || _isMusicPlaying) return;

    try {
      await _musicPlayer.play(AssetSource(_musicAsset));
      _isMusicPlaying = true;
    } catch (e) {
      _isMusicPlaying = false;
    }
  }

  static Future<void> stopBackgroundMusic() async {
    if (!_isMusicPlaying) return;
    await _musicPlayer.stop();
    _isMusicPlaying = false;
  }

  static Future<void> pauseBackgroundMusic() async {
    if (!_isMusicPlaying) return;
    await _musicPlayer.pause();
  }

  static Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled || !_isMusicPlaying) return;
    await _musicPlayer.resume();
  }

  /// Applies a music on/off change immediately, so the toggle in Settings has
  /// an audible effect rather than taking hold on the next launch.
  static Future<void> toggleBackgroundMusic(bool enable) async {
    _musicEnabled = enable;

    if (enable) {
      await startBackgroundMusic();
    } else {
      await stopBackgroundMusic();
    }
  }

  /// Applies a sound-effects on/off change immediately.
  static void toggleSoundEffects(bool enable) {
    _sfxEnabled = enable;
  }

  // ====================
  // CLEANUP
  // ====================

  static Future<void> dispose() async {
    await _musicPlayer.dispose();
    for (final player in _sfxPool) {
      await player.dispose();
    }
    _initialised = false;
  }
}
