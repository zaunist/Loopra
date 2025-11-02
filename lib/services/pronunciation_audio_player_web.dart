import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:flutter/foundation.dart';

class PronunciationAudioPlayer {
  web.HTMLAudioElement? _element;

  Future<void> play(
    String url,
    double volume, {
    bool useAnonymousCrossOrigin = false,
  }) async {
    await stop();

    final web.HTMLAudioElement element = web.HTMLAudioElement()
      ..src = url
      ..volume = volume.clamp(0, 1).toDouble()
      ..autoplay = true
      ..controls = false
      ..preload = 'auto';
    if (useAnonymousCrossOrigin) {
      element.crossOrigin = 'anonymous';
    }

    element.onError.listen((web.Event event) {
      final web.MediaError? mediaError = element.error;
      debugPrint(
        'Web pronunciation audio failed to load $url: ${mediaError?.message ?? event.type}',
      );
    });

    _element = element;

    try {
      await element.play().toDart;
    } catch (error, stackTrace) {
      debugPrint('Pronunciation audio playback failed for $url: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Future<void> stop() async {
    final web.SpeechSynthesis? synthesis = web.window.speechSynthesis;
    synthesis?.cancel();

    final web.HTMLAudioElement? element = _element;
    if (element == null) {
      return;
    }
    try {
      element.pause();
    } catch (_) {
      // Swallow pause errors; element might not be in playing state.
    }
    element.src = '';
    element.removeAttribute('src');
    element.load();
    _element = null;
  }

  Future<void> dispose() async {
    await stop();
  }

  Future<bool> speakWithWebSpeech(
    String text, {
    String? languageCode,
  }) async {
    final web.SpeechSynthesis? synthesis = web.window.speechSynthesis;
    if (synthesis == null) {
      return false;
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    await stop();
    final web.SpeechSynthesisUtterance utterance =
        web.SpeechSynthesisUtterance(trimmed);
    if (languageCode != null && languageCode.isNotEmpty) {
      utterance.lang = languageCode;
    }
    synthesis.speak(utterance);
    return true;
  }
}
