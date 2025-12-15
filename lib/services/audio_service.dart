import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class AudioService {
  // Audio players
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();

  // Music state
  static bool _isMusicPlaying = false;

  // ====================
  // INITIALIZATION
  // ====================
  static Future<void> initialize() async {
    // Set music player to loop
    _musicPlayer.setReleaseMode(ReleaseMode.loop);

    // Set volume levels
    _musicPlayer.setVolume(0.3); // Background music quieter
    _sfxPlayer.setVolume(0.6); // Sound effects louder

    print('🎵 Audio service initialized');
  }

  // ====================
  // BACKGROUND MUSIC
  // ====================
  static Future<void> startBackgroundMusic() async {
    final musicEnabled = await SettingsService.getMusic();

    if (!musicEnabled || _isMusicPlaying) return;

    try {
      // Play relaxing background music
      // You'll need to add a music file to assets/audio/background_music.mp3
      await _musicPlayer.play(AssetSource('audio/background_music.mp3'));
      _isMusicPlaying = true;
      print('🎵 Background music started');
    } catch (e) {
      print('⚠️ Error playing background music: $e');
    }
  }

  static Future<void> stopBackgroundMusic() async {
    if (!_isMusicPlaying) return;

    await _musicPlayer.stop();
    _isMusicPlaying = false;
    print('🎵 Background music stopped');
  }

  static Future<void> pauseBackgroundMusic() async {
    if (!_isMusicPlaying) return;

    await _musicPlayer.pause();
    print('🎵 Background music paused');
  }

  static Future<void> resumeBackgroundMusic() async {
    final musicEnabled = await SettingsService.getMusic();

    if (!musicEnabled || !_isMusicPlaying) return;

    await _musicPlayer.resume();
    print('🎵 Background music resumed');
  }

  static Future<void> toggleBackgroundMusic(bool enable) async {
    if (enable && !_isMusicPlaying) {
      await startBackgroundMusic();
    } else if (!enable && _isMusicPlaying) {
      await stopBackgroundMusic();
    }
  }

  // ====================
  // SOUND EFFECTS
  // ====================
  static Future<void> playSound(String soundName) async {
    final sfxEnabled = await SettingsService.getSoundEffects();

    if (!sfxEnabled) return;

    try {
      // Stop any currently playing sound effect first
      await _sfxPlayer.stop();

      // Play the requested sound
      // You'll need to add sound files to assets/audio/
      await _sfxPlayer.play(AssetSource('audio/$soundName.mp3'));
      print('🔊 Played sound: $soundName');
    } catch (e) {
      print('⚠️ Error playing sound $soundName: $e');
    }
  }

  // Specific sound effect methods
  static Future<void> playTapSound() => playSound('tap');
  static Future<void> playNumberPlaceSound() => playSound('number_place');
  static Future<void> playEraseSound() => playSound('erase');
  static Future<void> playErrorSound() => playSound('error');
  static Future<void> playSuccessSound() => playSound('success');
  static Future<void> playButtonSound() => playSound('button');
  static Future<void> playToggleSound() => playSound('toggle');

  // ====================
  // CLEANUP
  // ====================
  static Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
    print('🎵 Audio service disposed');
  }
}
