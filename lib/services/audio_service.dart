import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pronunciation_audio_player.dart';

enum PronunciationVariant { us, uk }

enum _PronunciationEngine { youdao, googleTranslate }

class _PronunciationProfile {
  const _PronunciationProfile({
    this.le,
    this.supportsVariants = false,
    this.prefersPhoneticInput = false,
    this.inputSanitizer,
    this.googleLanguageCode,
    this.webSpeechLanguageCode,
    List<_PronunciationEngine>? engines,
  }) : engines =
            engines ?? const <_PronunciationEngine>[_PronunciationEngine.youdao];

  final String? le;
  final bool supportsVariants;
  final bool prefersPhoneticInput;
  final String Function(String text)? inputSanitizer;
  final String? googleLanguageCode;
  final String? webSpeechLanguageCode;
  final List<_PronunciationEngine> engines;

  String prepareInput(String text) {
    final String sanitized = inputSanitizer != null ? inputSanitizer!(text) : text;
    return sanitized.trim();
  }

  List<String> buildUrls(String text, PronunciationVariant variant) {
    final String trimmed = prepareInput(text);
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    final String encoded = Uri.encodeComponent(trimmed);
    final List<String> urls = <String>[];
    for (final _PronunciationEngine engine in engines) {
      switch (engine) {
        case _PronunciationEngine.youdao:
          final List<String> params = <String>['audio=$encoded'];
          if (supportsVariants) {
            params.add('type=${variant == PronunciationVariant.uk ? '1' : '2'}');
          }
          if (le != null && le!.isNotEmpty) {
            params.add('le=${Uri.encodeComponent(le!)}');
          }
          urls.add('https://dict.youdao.com/dictvoice?${params.join('&')}');
          break;
        case _PronunciationEngine.googleTranslate:
          final String? language = googleLanguageCode;
          if (language == null || language.isEmpty) {
            continue;
          }
          final String encodedLanguage = Uri.encodeComponent(language);
          urls.add(
            'https://translate.googleapis.com/translate_tts'
            '?ie=UTF-8&client=tw-ob&tl=$encodedLanguage&q=$encoded',
          );
          break;
      }
    }
    return urls;
  }
}

class AudioService {
  // Pronunciation service mappings. Extend this map when new languages are added
  // or when a language needs a different provider/fallback chain.
  static const Map<String, _PronunciationProfile> _profiles =
      <String, _PronunciationProfile>{
    'en': _PronunciationProfile(
      supportsVariants: true,
      webSpeechLanguageCode: 'en-US',
    ),
    'code': _PronunciationProfile(
      supportsVariants: true,
      webSpeechLanguageCode: 'en-US',
    ),
    'ja': _PronunciationProfile(
      le: 'jap',
      prefersPhoneticInput: true,
      inputSanitizer: _stripJapaneseFurigana,
      webSpeechLanguageCode: 'ja-JP',
    ),
    'zh': _PronunciationProfile(
      le: 'zh',
      webSpeechLanguageCode: 'zh-CN',
    ),
    'de': _PronunciationProfile(
      le: 'de',
      googleLanguageCode: 'de',
      webSpeechLanguageCode: 'de-DE',
      engines: <_PronunciationEngine>[
        _PronunciationEngine.youdao,
        _PronunciationEngine.googleTranslate,
      ],
    ),
    'fr': _PronunciationProfile(
      le: 'fr',
      webSpeechLanguageCode: 'fr-FR',
    ),
    'es': _PronunciationProfile(
      le: 'es',
      webSpeechLanguageCode: 'es-ES',
    ),
    'ar': _PronunciationProfile(
      le: 'ar',
      webSpeechLanguageCode: 'ar-SA',
    ),
    'ko': _PronunciationProfile(
      le: 'ko',
      webSpeechLanguageCode: 'ko-KR',
    ),
    'it': _PronunciationProfile(
      le: 'it',
      webSpeechLanguageCode: 'it-IT',
    ),
    'ru': _PronunciationProfile(
      le: 'ru',
      webSpeechLanguageCode: 'ru-RU',
    ),
    'pt': _PronunciationProfile(
      le: 'pt',
      webSpeechLanguageCode: 'pt-BR',
    ),
    'kk': _PronunciationProfile(
      googleLanguageCode: 'kk',
      webSpeechLanguageCode: 'kk-KZ',
      engines: <_PronunciationEngine>[],
    ),
    'id': _PronunciationProfile(
      le: 'id',
      webSpeechLanguageCode: 'id-ID',
    ),
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
    final List<String> urls = profile.buildUrls(text, variant);
    if (urls.isEmpty) {
      final bool spoken = await _fallbackToWebSpeech(text, profile);
      if (spoken) {
        debugPrint(
          'Pronunciation fallback using Web Speech API for "$text" (${profile.webSpeechLanguageCode ?? profile.googleLanguageCode ?? 'default'}).',
        );
        return;
      }
      return;
    }
    for (int index = 0; index < urls.length; index++) {
      final String url = urls[index];
      final bool isLastAttempt = index == urls.length - 1;
      final bool requiresCrossOrigin = _requiresAnonymousCrossOrigin(url);
      try {
        await _pronunciationPlayer.play(
          url,
          volume,
          useAnonymousCrossOrigin: requiresCrossOrigin,
        );
        return;
      } on MissingPluginException {
        _isAudioPlaybackAvailable = false;
        return;
      } on PlatformException catch (error, stackTrace) {
        debugPrint('Pronunciation playback failed for $url: $error');
        debugPrint('$stackTrace');
        if (!isLastAttempt) {
          debugPrint(
            'Retrying pronunciation playback with fallback source (${index + 2}/${urls.length}).',
          );
          continue;
        }
        if (kIsWeb && error.code == 'WebAudioError') {
          return;
        }
        return;
      } catch (error, stackTrace) {
        debugPrint('Pronunciation playback failed for $url: $error');
        debugPrint('$stackTrace');
        if (!isLastAttempt) {
          debugPrint(
            'Retrying pronunciation playback with fallback source (${index + 2}/${urls.length}).',
          );
          continue;
        }
        if (kIsWeb) {
          return;
        }
        return;
      }
    }
    final bool spoken = await _fallbackToWebSpeech(text, profile);
    if (spoken) {
      debugPrint(
        'Pronunciation fallback using Web Speech API for "$text" (${profile.webSpeechLanguageCode ?? profile.googleLanguageCode ?? 'default'}).',
      );
      return;
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

  bool _requiresAnonymousCrossOrigin(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }
    const Set<String> allowAnonymousHosts = <String>{
      // Populate when a provider explicitly requires CORS-enabled playback.
    };
    final String host = uri.host.toLowerCase();
    return allowAnonymousHosts.contains(host);
  }

  Future<bool> _fallbackToWebSpeech(
    String text,
    _PronunciationProfile profile,
  ) async {
    if (!kIsWeb) {
      return false;
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final String? language = (profile.webSpeechLanguageCode != null &&
            profile.webSpeechLanguageCode!.isNotEmpty)
        ? profile.webSpeechLanguageCode
        : profile.googleLanguageCode;
    return _pronunciationPlayer.speakWithWebSpeech(
      trimmed,
      languageCode: language,
    );
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
