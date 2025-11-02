import 'package:audioplayers/audioplayers.dart';

class PronunciationAudioPlayer {
  PronunciationAudioPlayer() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  final AudioPlayer _player = AudioPlayer(playerId: 'pronunciation');

  Future<void> play(
    String url,
    double volume, {
    bool useAnonymousCrossOrigin = false,
  }) async {
    await _player.stop();
    await _player.setVolume(volume);
    await _player.play(UrlSource(url));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<bool> speakWithWebSpeech(
    String text, {
    String? languageCode,
  }) async {
    return false;
  }
}
