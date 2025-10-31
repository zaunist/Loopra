import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/dictionary.dart';
import '../models/word_entry.dart';
import '../services/audio_service.dart';
import '../services/dictionary_repository.dart';

enum LetterState { idle, correct, wrong }

class TypingController extends ChangeNotifier {
  TypingController(this._repository, this._audioService);

  final DictionaryRepository _repository;
  final AudioService _audioService;

  DictionaryMeta? _selectedDictionary;
  List<DictionaryMeta> _dictionaries = const <DictionaryMeta>[];
  int _selectedChapter = 0;
  int _chapterCount = 0;

  List<WordEntry> _chapterWords = const <WordEntry>[];
  int _currentIndex = 0;

  String _input = '';
  List<LetterState> _letterStates = const <LetterState>[];
  bool _hasWrong = false;
  int _wrongAttempts = 0;

  bool _showTranslation = true;
  bool _ignoreCase = true;
  bool _keySoundEnabled = true;
  bool _feedbackSoundEnabled = true;
  bool _autoPronunciationEnabled = false;
  PronunciationVariant _pronunciationVariant = PronunciationVariant.us;

  bool _isLoading = false;
  bool _isTyping = false;
  bool _isFinished = false;

  int _elapsedSeconds = 0;
  Timer? _timer;
  int _correctKeystrokes = 0;
  int _wrongKeystrokes = 0;
  int _completedWords = 0;

  bool _disposed = false;

  static const Duration _resetDelay = Duration(milliseconds: 320);

  static final Set<LogicalKeyboardKey> _ignoredKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.audioVolumeUp,
    LogicalKeyboardKey.audioVolumeDown,
    LogicalKeyboardKey.audioVolumeMute,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.clear,
    LogicalKeyboardKey.home,
  };

  Future<void> initialise() async {
    _isLoading = true;
    notifyListeners();

    final List<DictionaryMeta> dictionaries = await _repository.loadManifest();
    _dictionaries = dictionaries;
    _selectedDictionary = dictionaries.isNotEmpty ? dictionaries.first : null;

    if (_selectedDictionary != null) {
      await _reloadDictionaryChapter();
    }

    _isLoading = false;
    notifyListeners();
  }

  List<DictionaryMeta> get dictionaries => _dictionaries;

  DictionaryMeta? get selectedDictionary => _selectedDictionary;

  int get selectedChapter => _selectedChapter;

  int get chapterCount => _chapterCount;

  bool get isLoading => _isLoading;

  bool get isTyping => _isTyping;

  bool get isFinished => _isFinished;

  bool get showTranslation => _showTranslation;

  bool get ignoreCase => _ignoreCase;

  bool get keySoundEnabled => _keySoundEnabled;

  bool get feedbackSoundEnabled => _feedbackSoundEnabled;

  bool get autoPronunciationEnabled => _autoPronunciationEnabled;

  PronunciationVariant get pronunciationVariant => _pronunciationVariant;

  bool get supportsPronunciation {
    final DictionaryMeta? dict = _selectedDictionary;
    if (dict == null) {
      return false;
    }
    return dict.language == DictionaryLanguage.english || dict.language == DictionaryLanguage.code;
  }

  int get elapsedSeconds => _elapsedSeconds;

  int get completedWords => _completedWords;

  int get remainingWords => _chapterWords.length - _currentIndex - (_isFinished ? 0 : 1);

  int get totalWords => _chapterWords.length;

  int get correctKeystrokes => _correctKeystrokes;

  int get wrongKeystrokes => _wrongKeystrokes;

  double get accuracy {
    final int total = _correctKeystrokes + _wrongKeystrokes;
    if (total == 0) {
      return 1;
    }
    return _correctKeystrokes / total;
  }

  int get wordsPerMinute {
    if (_elapsedSeconds == 0) {
      return 0;
    }
    final double perMinute = (_completedWords / _elapsedSeconds) * 60;
    return perMinute.isFinite ? perMinute.round() : 0;
  }

  WordEntry? get currentWord =>
      _currentIndex >= 0 && _currentIndex < _chapterWords.length ? _chapterWords[_currentIndex] : null;

  List<WordEntry> get words => _chapterWords;

  int get currentIndex => _currentIndex;

  List<LetterState> get letterStates => _letterStates;

  String get input => _input;

  bool get canSkipCurrentWord => _wrongAttempts >= 4 && !_isFinished && !_isLoading && currentWord != null;

  bool get isSessionReady => _chapterWords.isNotEmpty;

  Future<void> selectDictionary(String id) async {
    if (_selectedDictionary?.id == id) {
      return;
    }
    _isLoading = true;
    notifyListeners();

    final List<DictionaryMeta> dictionaries = await _repository.loadManifest();
    _dictionaries = dictionaries;

    try {
      _selectedDictionary = _dictionaries.firstWhere((DictionaryMeta element) => element.id == id);
    } on StateError {
      _selectedDictionary = _dictionaries.isNotEmpty ? _dictionaries.first : null;
    }
    if (!supportsPronunciation && _autoPronunciationEnabled) {
      _autoPronunciationEnabled = false;
    }
    _selectedChapter = 0;
    await _reloadDictionaryChapter();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectChapter(int chapter) async {
    if (chapter == _selectedChapter) {
      return;
    }
    _isLoading = true;
    notifyListeners();

    _selectedChapter = chapter;
    await _reloadDictionaryChapter();

    _isLoading = false;
    notifyListeners();
  }

  void toggleTranslationVisibility(bool value) {
    if (_showTranslation == value) {
      return;
    }
    _showTranslation = value;
    notifyListeners();
  }

  void toggleIgnoreCase(bool value) {
    if (_ignoreCase == value) {
      return;
    }
    _ignoreCase = value;
    notifyListeners();
  }

  void toggleKeySound(bool value) {
    if (_keySoundEnabled == value) {
      return;
    }
    _keySoundEnabled = value;
    notifyListeners();
  }

  void toggleFeedbackSound(bool value) {
    if (_feedbackSoundEnabled == value) {
      return;
    }
    _feedbackSoundEnabled = value;
    notifyListeners();
  }

  void toggleAutoPronunciation(bool value) {
    if (!supportsPronunciation && value) {
      return;
    }
    if (_autoPronunciationEnabled == value) {
      return;
    }
    _autoPronunciationEnabled = value;
    notifyListeners();
    if (_autoPronunciationEnabled) {
      _announceCurrentWord();
    }
  }

  void setPronunciationVariant(PronunciationVariant variant) {
    if (_pronunciationVariant == variant) {
      return;
    }
    _pronunciationVariant = variant;
    notifyListeners();
    if (_autoPronunciationEnabled) {
      _announceCurrentWord();
    }
  }

  void playCurrentPronunciation() {
    final WordEntry? word = currentWord;
    final DictionaryMeta? dict = _selectedDictionary;
    if (word == null || dict == null || !supportsPronunciation) {
      return;
    }
    unawaited(_audioService.playPronunciation(
      word.headword,
      variant: _pronunciationVariant,
      language: dict.language,
    ));
  }

  void toggleTyping() {
    if (_isFinished || currentWord == null || _isLoading) {
      return;
    }

    if (_isTyping) {
      _isTyping = false;
      _cancelTimer();
    } else {
      _isTyping = true;
      _ensureTimer();
    }
    notifyListeners();
  }

  Future<void> restartChapter() async {
    if (_selectedDictionary == null) {
      return;
    }
    _isLoading = true;
    notifyListeners();
    await _reloadDictionaryChapter();
    _isLoading = false;
    notifyListeners();
  }

  bool handleKeyEvent(KeyEvent event) {
    if (_isLoading || _isFinished || currentWord == null) {
      return false;
    }
    if (event is! KeyDownEvent) {
      return false;
    }
    if (_ignoredKeys.contains(event.logicalKey)) {
      return true;
    }
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) {
      return true;
    }

    String? character = event.character;
    if (character == null || character.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        character = ' ';
      } else {
        return false;
      }
    }

    return handleCharacterInput(character);
  }

  bool handleCharacterInput(String character) {
    if (_isLoading || _isFinished || currentWord == null) {
      return false;
    }
    if (character.isEmpty) {
      return false;
    }

    if (!_isTyping) {
      _isTyping = true;
      _ensureTimer();
      notifyListeners();
    }

    if (_hasWrong) {
      return true;
    }

    final WordEntry word = currentWord!;
    final String expected = word.headword;
    if (_input.length >= expected.length) {
      return true;
    }

    final String effectiveChar = character[0];

    if (_keySoundEnabled) {
      unawaited(_audioService.playKeySound());
    }

    final int index = _input.length;
    final String expectedChar = expected[index];
    final String normalizedExpected = _ignoreCase ? expectedChar.toLowerCase() : expectedChar;
    final String normalizedInput = _ignoreCase ? effectiveChar.toLowerCase() : effectiveChar;

    if (normalizedInput == normalizedExpected) {
      _correctKeystrokes += 1;
      _letterStates[index] = LetterState.correct;
      _input += expectedChar;

      final bool finishedWord = _input.length >= expected.length;
      if (finishedWord) {
        _completedWords += 1;
        if (_feedbackSoundEnabled) {
          unawaited(_audioService.playCorrectSound());
        }
        _advanceToNextWord();
      }

      notifyListeners();
      return true;
    } else {
      _wrongKeystrokes += 1;
      _letterStates[index] = LetterState.wrong;
      _hasWrong = true;
      _wrongAttempts += 1;
      if (_feedbackSoundEnabled) {
        unawaited(_audioService.playWrongSound());
      }
      notifyListeners();

      final WordEntry snapshot = word;
      Future<void>.delayed(_resetDelay, () {
        if (_disposed || currentWord != snapshot) {
          return;
        }
        _input = '';
        _letterStates = List<LetterState>.generate(
          snapshot.displayWord.length,
          (_) => LetterState.idle,
        );
        _hasWrong = false;
        notifyListeners();
      });
      return true;
    }
  }

  void skipCurrentWord() {
    if (!canSkipCurrentWord) {
      return;
    }

    _advanceToNextWord();
    notifyListeners();
  }

  Future<void> _reloadDictionaryChapter() async {
    final DictionaryMeta? meta = _selectedDictionary;
    if (meta == null) {
      _chapterWords = const <WordEntry>[];
      _chapterCount = 0;
      _currentIndex = 0;
      _resetCurrentWordState();
      return;
    }

    _cancelTimer();

    if (!supportsPronunciation && _autoPronunciationEnabled) {
      _autoPronunciationEnabled = false;
    }

    final List<WordEntry> newWords = await _repository.loadChapter(id: meta.id, chapter: _selectedChapter);
    _chapterWords = newWords;
    _chapterCount = await _repository.chapterCount(meta.id);
    _currentIndex = 0;
    _resetCurrentWordState();
    _announceCurrentWord();

    _elapsedSeconds = 0;
    _correctKeystrokes = 0;
    _wrongKeystrokes = 0;
    _completedWords = 0;

    _isTyping = false;
    _isFinished = false;
    _hasWrong = false;
    _wrongAttempts = 0;
  }

  void _advanceToNextWord() {
    _hasWrong = false;
    _wrongAttempts = 0;

    _currentIndex += 1;
    if (_currentIndex >= _chapterWords.length) {
      _finishSession();
    } else {
      _resetCurrentWordState();
      _announceCurrentWord();
    }
  }

  void _resetCurrentWordState() {
    final WordEntry? word = currentWord;
    if (word == null) {
      _input = '';
      _letterStates = const <LetterState>[];
      return;
    }

    _input = '';
    _letterStates = List<LetterState>.generate(
      word.displayWord.length,
      (_) => LetterState.idle,
    );
  }

  void _announceCurrentWord() {
    if (!_autoPronunciationEnabled || !supportsPronunciation) {
      return;
    }
    final WordEntry? word = currentWord;
    final DictionaryMeta? dict = _selectedDictionary;
    if (word == null || dict == null) {
      return;
    }
    unawaited(_audioService.playPronunciation(
      word.headword,
      variant: _pronunciationVariant,
      language: dict.language,
    ));
  }

  void _finishSession() {
    _isFinished = true;
    _isTyping = false;
    _cancelTimer();
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      notifyListeners();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimer();
    super.dispose();
  }
}
