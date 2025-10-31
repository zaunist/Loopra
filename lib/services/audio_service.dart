import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pronunciation_audio_player.dart';

enum PronunciationVariant { us, uk }

class _PronunciationProfile {
  const _PronunciationProfile({
    this.le,
    this.supportsVariants = false,
    this.prefersPhoneticInput = false,
    this.inputSanitizer,
  });

  final String? le;
  final bool supportsVariants;
  final bool prefersPhoneticInput;
  final String Function(String text)? inputSanitizer;

  String prepareInput(String text) {
    final String sanitized = inputSanitizer != null ? inputSanitizer!(text) : text;
    return sanitized.trim();
  }

  String buildUrl(String text, PronunciationVariant variant) {
    final String trimmed = prepareInput(text);
    if (trimmed.isEmpty) {
      return '';
    }
    final String encoded = Uri.encodeComponent(trimmed);
    final List<String> params = <String>['audio=$encoded'];
    if (supportsVariants) {
      params.add('type=${variant == PronunciationVariant.uk ? '1' : '2'}');
    }
    if (le != null && le!.isNotEmpty) {
      params.add('le=${Uri.encodeComponent(le!)}');
    }
    return 'https://dict.youdao.com/dictvoice?${params.join('&')}';
  }
}

class AudioService {
  // Youdao voice service language mappings. Extend this map when new languages are added.
  static const Map<String, _PronunciationProfile> _profiles =
      <String, _PronunciationProfile>{
    'en': _PronunciationProfile(supportsVariants: true),
    'code': _PronunciationProfile(supportsVariants: true),
    'ja': _PronunciationProfile(
      le: 'jap',
      prefersPhoneticInput: true,
      inputSanitizer: _stripJapaneseFurigana,
    ),
    'zh': _PronunciationProfile(le: 'zh'),
    'de': _PronunciationProfile(le: 'de'),
    'fr': _PronunciationProfile(le: 'fr'),
    'es': _PronunciationProfile(le: 'es'),
    'ar': _PronunciationProfile(le: 'ar'),
    'ko': _PronunciationProfile(le: 'ko'),
    'it': _PronunciationProfile(le: 'it'),
    'ru': _PronunciationProfile(le: 'ru'),
    'pt': _PronunciationProfile(le: 'pt'),
  };

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

  bool supportsPronunciation(String languageCode) =>
      _profileFor(languageCode) != null;

  bool supportsPronunciationVariants(String languageCode) =>
      _profileFor(languageCode)?.supportsVariants ?? false;

  bool prefersPhoneticInput(String languageCode) =>
      _profileFor(languageCode)?.prefersPhoneticInput ?? false;

  String? preparePronunciationText(String languageCode, String text) {
    final _PronunciationProfile? profile = _profileFor(languageCode);
    if (profile == null) {
      final String trimmed = text.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final String prepared = profile.prepareInput(text);
    if (prepared.isEmpty) {
      return null;
    }
    return prepared;
  }

  Future<void> playPronunciation(
    String text, {
    PronunciationVariant variant = PronunciationVariant.us,
    required String languageCode,
    double volume = 0.8,
  }) async {
    if (!_isAudioPlaybackAvailable) {
      return;
    }
    final _PronunciationProfile? profile = _profileFor(languageCode);
    if (profile == null) {
      return;
    }
    final String url = profile.buildUrl(text, variant);
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
      debugPrint('Pronunciation playback failed for $url: $error');
      debugPrint('$stackTrace');
    } catch (error, stackTrace) {
      if (kIsWeb) {
        debugPrint('Pronunciation playback failed for $url: $error');
        debugPrint('$stackTrace');
        return;
      }
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

  static String _stripJapaneseFurigana(String text) {
    final RegExp parentheses = RegExp(r'[（(][^）)]*[）)]');
    final String withoutFurigana = text.replaceAll(parentheses, '');
    final String collapsedWhitespace =
        withoutFurigana.replaceAll(RegExp(r'\s+'), '');
    return collapsedWhitespace;
  }

  _PronunciationProfile? _profileFor(String languageCode) {
    final String normalized = _normalizeLanguageCode(languageCode);
    if (normalized.isEmpty) {
      return null;
    }
    final _PronunciationProfile? direct = _profiles[normalized];
    if (direct != null) {
      return direct;
    }
    final int hyphenIndex = normalized.indexOf('-');
    if (hyphenIndex != -1) {
      final String base = normalized.substring(0, hyphenIndex);
      return _profiles[base];
    }
    return null;
  }

  String _normalizeLanguageCode(String languageCode) =>
      languageCode.trim().toLowerCase().replaceAll('_', '-');
}
