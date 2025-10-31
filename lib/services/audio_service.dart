import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/dictionary.dart';
import 'pronunciation_audio_player.dart';

enum PronunciationVariant { us, uk }

class AudioService {
  AudioService() {
    // Keep the Flutter default prefix so both mobile and web resolve to assets/assets/… on web builds.
    final AudioCache cache = AudioCache.instance = AudioCache(
      prefix: 'assets/',
    );

    if (!kIsWeb) {
      AudioPlayer.global.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.assistanceSonification,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: <AVAudioSessionOptions>[
              AVAudioSessionOptions.mixWithOthers,
            ],
          ),
        ),
      );
    }

    _keyPlayer
      ..audioCache = cache
      ..setReleaseMode(ReleaseMode.stop)
      ..setPlayerMode(PlayerMode.lowLatency);

    _correctPlayer
      ..audioCache = cache
      ..setReleaseMode(ReleaseMode.stop);

    _wrongPlayer
      ..audioCache = cache
      ..setReleaseMode(ReleaseMode.stop);

    unawaited(_preloadAssets());
  }

  static const String _keySoundAsset = 'sounds/key.wav';
  static const String _correctSoundAsset = 'sounds/correct.wav';
  static const String _wrongSoundAsset = 'sounds/beep.wav';

  bool _isAudioPlaybackAvailable = true;
  final Set<String> _failedAssets = <String>{};

  Future<void> _preloadAssets() async {
    try {
      await AudioCache.instance.loadAll(<String>[
        _keySoundAsset,
        _correctSoundAsset,
        _wrongSoundAsset,
      ]);
    } catch (error, stackTrace) {
      debugPrint('Audio asset preload failed: $error');
      debugPrint('$stackTrace');
    }
  }

  final AudioPlayer _keyPlayer = AudioPlayer(playerId: 'key_sound');
  final AudioPlayer _correctPlayer = AudioPlayer(playerId: 'correct_sound');
  final AudioPlayer _wrongPlayer = AudioPlayer(playerId: 'wrong_sound');
  final PronunciationAudioPlayer _pronunciationPlayer =
      PronunciationAudioPlayer();

  Future<void> playKeySound({double volume = 0.5}) async {
    await _playAsset(_keyPlayer, _keySoundAsset, volume: volume);
  }

  Future<void> playCorrectSound({double volume = 0.5}) async {
    await _playAsset(_correctPlayer, _correctSoundAsset, volume: volume);
  }

  Future<void> playWrongSound({double volume = 0.6}) async {
    await _playAsset(_wrongPlayer, _wrongSoundAsset, volume: volume);
  }

  Future<void> playPronunciation(
    String word, {
    PronunciationVariant variant = PronunciationVariant.us,
    required DictionaryLanguage language,
    double volume = 0.8,
  }) async {
    if (!_isAudioPlaybackAvailable) {
      return;
    }
    final String url = _buildPronunciationUrl(
      word,
      variant: variant,
      language: language,
    );
    if (url.isEmpty) {
      return;
    }
    try {
      await _pronunciationPlayer.play(url, volume);
    } on MissingPluginException {
      _isAudioPlaybackAvailable = false;
    } on PlatformException catch (error, stackTrace) {
      if (kIsWeb && error.code == 'WebAudioError') {
        // Browsers can block remote audio without proper CORS headers; keep other sounds alive.
        debugPrint(
          'Web pronunciation playback failed for $url: ${error.message}',
        );
        return;
      }
      _isAudioPlaybackAvailable = false;
      debugPrint('Pronunciation playback failed for $url: $error');
      debugPrint('$stackTrace');
    } catch (error, stackTrace) {
      if (kIsWeb) {
        debugPrint('Pronunciation playback failed for $url: $error');
        debugPrint('$stackTrace');
        return;
      }
      _isAudioPlaybackAvailable = false;
      debugPrint('Pronunciation playback failed for $url: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> dispose() async {
    await _keyPlayer.dispose();
    await _correctPlayer.dispose();
    await _wrongPlayer.dispose();
    await _pronunciationPlayer.dispose();
  }

  Future<void> _playAsset(
    AudioPlayer player,
    String asset, {
    double volume = 1,
  }) async {
    if (!_isAudioPlaybackAvailable) {
      return;
    }
    if (_failedAssets.contains(asset)) {
      return;
    }
    try {
      await player.play(AssetSource(asset), volume: volume);
    } on MissingPluginException {
      _isAudioPlaybackAvailable = false;
    } on PlatformException catch (error, stackTrace) {
      if (kIsWeb && error.code == 'WebAudioError') {
        // Browsers can reject autoplay attempts until a gesture unlocks audio; keep retrying.
        debugPrint('Web audio playback failed for $asset: ${error.message}');
        return;
      }
      debugPrint('Audio playback failed for $asset: $error');
      debugPrint('$stackTrace');
      _failedAssets.add(asset);
    } catch (error, stackTrace) {
      if (kIsWeb) {
        // Some browsers throw DomException('NotAllowedError') before audio is unlocked by interaction.
        debugPrint('Audio playback failed for $asset: $error');
        debugPrint('$stackTrace');
        return;
      }
      debugPrint('Audio playback failed for $asset: $error');
      debugPrint('$stackTrace');
      _failedAssets.add(asset);
    }
  }

  String _buildPronunciationUrl(
    String word, {
    required PronunciationVariant variant,
    required DictionaryLanguage language,
  }) {
    if (word.isEmpty) {
      return '';
    }
    final String encoded = Uri.encodeComponent(word);

    if (language == DictionaryLanguage.english ||
        language == DictionaryLanguage.code) {
      final String type = variant == PronunciationVariant.uk ? '1' : '2';
      return 'https://dict.youdao.com/dictvoice?audio=$encoded&type=$type';
    }

    // Other languages are not yet supported; returning empty string avoids erroneous requests.
    return '';
  }
}
