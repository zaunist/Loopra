import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/dictionary.dart';
import '../models/practice_statistics.dart';
import '../models/word_entry.dart';
import '../services/audio_service.dart';
import '../services/dictionary_repository.dart';
import 'statistics_controller.dart';

enum LetterState { idle, correct, wrong }

class TypingController extends ChangeNotifier {
  TypingController(this._repository, this._audioService, this._statistics) {
    _statistics.addListener(_handleStatisticsUpdated);
  }

  final DictionaryRepository _repository;
  final AudioService _audioService;
  final StatisticsController _statistics;

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
  bool _autoPronunciationEnabled = true;
  PronunciationVariant _pronunciationVariant = PronunciationVariant.us;
  bool _dictationMode = false;

  bool _isLoading = false;
  bool _isTyping = false;
  bool _isFinished = false;

  int _elapsedSeconds = 0;
  Timer? _timer;
  int _correctKeystrokes = 0;
  int _wrongKeystrokes = 0;
  int _completedWords = 0;
  DateTime? _sessionStartedAt;
  bool _sessionRecorded = false;

  bool _disposed = false;
  PracticeSessionRecord? _pendingSessionProgress;
  String? _lastAppliedSessionId;

  bool get _shouldUseSystemKeyFeedback {
    if (kIsWeb) {
      return false;
    }
    final TargetPlatform platform = defaultTargetPlatform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

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
    unawaited(_statistics.initialise());

    final List<DictionaryMeta> dictionaries = await _repository.loadManifest();
    _dictionaries = dictionaries;
    _selectedDictionary = dictionaries.isNotEmpty ? dictionaries.first : null;

    if (_selectedDictionary != null) {
      await _reloadDictionaryChapter();
    }

    _isLoading = false;
    notifyListeners();
    unawaited(_applyPendingSessionIfPossible());
  }

  List<DictionaryMeta> get dictionaries => _dictionaries;

  DictionaryMeta? get selectedDictionary => _selectedDictionary;

  bool get canManageDictionaries => _repository.supportsDictionaryManagement;

  bool get canDeleteSelectedDictionary => _selectedDictionary?.isCustom == true;

  int get selectedChapter => _selectedChapter;

  int get chapterCount => _chapterCount;

  bool get hasNextChapter => _chapterCount > 0 && (_selectedChapter + 1) < _chapterCount;

  bool get isLoading => _isLoading;

  bool get isTyping => _isTyping;

  bool get isFinished => _isFinished;

  bool get showTranslation => _showTranslation;

  bool get ignoreCase => _ignoreCase;

  bool get keySoundEnabled => _keySoundEnabled;

  bool get feedbackSoundEnabled => _feedbackSoundEnabled;

  bool get autoPronunciationEnabled => _autoPronunciationEnabled;

  PronunciationVariant get pronunciationVariant => _pronunciationVariant;

  bool get dictationMode => _dictationMode;

  bool get supportsPronunciation {
    final DictionaryMeta? dict = _selectedDictionary;
    if (dict == null) {
      return false;
    }
    return _audioService.supportsPronunciation(dict.normalizedLanguageCode);
  }

  bool get supportsPronunciationVariants {
    final DictionaryMeta? dict = _selectedDictionary;
    if (dict == null) {
      return false;
    }
    return _audioService.supportsPronunciationVariants(dict.normalizedLanguageCode);
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

  void _handleStatisticsUpdated() {
    if (!_statistics.isReady) {
      return;
    }
    final List<PracticeSessionRecord> sessions = _statistics.sessions;
    if (sessions.isEmpty) {
      return;
    }
    final PracticeSessionRecord latest = sessions.last;
    if (latest.id.isEmpty) {
      return;
    }
    if (_lastAppliedSessionId == latest.id) {
      return;
    }
    if (_selectedDictionary?.id == latest.dictionaryId && _selectedChapter == latest.chapterIndex) {
      _lastAppliedSessionId = latest.id;
      return;
    }
    _pendingSessionProgress = latest;
    unawaited(_applyPendingSessionIfPossible());
  }

  Future<void> selectDictionary(String id) async {
    if (_selectedDictionary?.id == id) {
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      await _refreshDictionaries(
        preferId: id,
        resetChapter: true,
        refresh: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DictionaryMeta> importDictionaryFromContent(String content) async {
    _isLoading = true;
    notifyListeners();
    try {
      final DictionaryMeta meta = await _repository.importDictionary(content);
      await _refreshDictionaries(
        preferId: meta.id,
        resetChapter: true,
        ignorePreviousSelection: true,
        refresh: true,
      );
      return meta;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DictionaryMeta> importDictionaryFromPath(String path) async {
    final String content = await _repository.readExternalFile(path);
    return importDictionaryFromContent(content);
  }

  Future<void> deleteDictionary(String id) async {
    final bool deletingSelected = _selectedDictionary?.id == id;
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.deleteDictionary(id);
      await _refreshDictionaries(
        resetChapter: true,
        ignorePreviousSelection: deletingSelected,
        refresh: true,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSelectedDictionary() async {
    final DictionaryMeta? meta = _selectedDictionary;
    if (meta == null) {
      return;
    }
    await deleteDictionary(meta.id);
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

  Future<void> goToNextChapter() async {
    if (!hasNextChapter || _isLoading) {
      return;
    }
    await selectChapter(_selectedChapter + 1);
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

  void toggleDictationMode(bool value) {
    if (_dictationMode == value) {
      return;
    }
    _dictationMode = value;
    notifyListeners();
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
    final String? pronunciationText = _pronunciationTextFor(word, dict);
    if (pronunciationText == null) {
      return;
    }
    unawaited(_audioService.playPronunciation(
      pronunciationText,
      variant: _pronunciationVariant,
      languageCode: dict.normalizedLanguageCode,
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
      _ensureSessionStarted();
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
      _ensureSessionStarted();
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

    if (_keySoundEnabled && !_shouldUseSystemKeyFeedback) {
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

  Future<void> _applyPendingSessionIfPossible() async {
    final PracticeSessionRecord? session = _pendingSessionProgress;
    if (session == null) {
      return;
    }
    if (!_statistics.isReady) {
      return;
    }
    if (_isTyping || _isFinished || _isLoading) {
      return;
    }
    if (_dictionaries.isEmpty) {
      return;
    }

    final DictionaryMeta? dictionary = _findDictionaryById(_dictionaries, session.dictionaryId);
    if (dictionary == null) {
      return;
    }

    // Clear pending marker before making recursive updates to avoid re-entry loops.
    _pendingSessionProgress = null;

    if (_selectedDictionary?.id != dictionary.id) {
      await _refreshDictionaries(
        preferId: dictionary.id,
        resetChapter: false,
        refresh: false,
      );
    }

    final int chapterCount = _chapterCount;
    if (chapterCount <= 0) {
      _lastAppliedSessionId = session.id;
      return;
    }
    final int targetChapter = session.chapterIndex.clamp(0, chapterCount - 1);
    if (_selectedChapter != targetChapter) {
      await selectChapter(targetChapter);
    }
    _lastAppliedSessionId = session.id;
  }

  Future<void> _refreshDictionaries({
    String? preferId,
    bool resetChapter = false,
    bool ignorePreviousSelection = false,
    bool refresh = true,
  }) async {
    final String? previousId = ignorePreviousSelection ? null : _selectedDictionary?.id;
    final List<DictionaryMeta> fetched = await _repository.loadManifest(refresh: refresh);
    _dictionaries = fetched;

    DictionaryMeta? next;
    if (preferId != null) {
      next = _findDictionaryById(fetched, preferId);
    }
    if (next == null && previousId != null) {
      next = _findDictionaryById(fetched, previousId);
    }
    next ??= fetched.isNotEmpty ? fetched.first : null;

    final bool dictionaryChanged = next?.id != previousId;
    _selectedDictionary = next;

    if (_selectedDictionary == null) {
      _selectedChapter = 0;
      _chapterCount = 0;
      _chapterWords = const <WordEntry>[];
      _currentIndex = 0;
      _resetCurrentWordState();
      return;
    }

    if (resetChapter || dictionaryChanged) {
      _selectedChapter = 0;
    }

    await _reloadDictionaryChapter();

    await _applyPendingSessionIfPossible();
  }

  DictionaryMeta? _findDictionaryById(List<DictionaryMeta> source, String id) {
    for (final DictionaryMeta meta in source) {
      if (meta.id == id) {
        return meta;
      }
    }
    return null;
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
    _resetSessionTracking();

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

  void _ensureSessionStarted() {
    if (_sessionStartedAt == null) {
      _sessionStartedAt = DateTime.now();
      _sessionRecorded = false;
    }
  }

  void _resetSessionTracking() {
    _sessionStartedAt = null;
    _sessionRecorded = false;
  }

  void _recordCompletedSession() {
    if (_sessionRecorded) {
      return;
    }
    final DictionaryMeta? dictionary = _selectedDictionary;
    if (dictionary == null) {
      _sessionRecorded = true;
      _sessionStartedAt = null;
      return;
    }
    final int total = totalWords;
    if (total <= 0 || _completedWords <= 0) {
      _sessionRecorded = true;
      _sessionStartedAt = null;
      return;
    }
    final int completed = _completedWords > total ? total : _completedWords;
    final DateTime completedAt = DateTime.now();
    final DateTime startedAt =
        _sessionStartedAt ?? completedAt.subtract(Duration(seconds: _elapsedSeconds));

    final PracticeSessionRecord session = PracticeSessionRecord(
      id: '${dictionary.id}-${completedAt.microsecondsSinceEpoch}',
      dictionaryId: dictionary.id,
      dictionaryName: dictionary.name,
      chapterIndex: _selectedChapter,
      totalWords: total,
      completedWords: completed,
      elapsedSeconds: _elapsedSeconds,
      correctKeystrokes: _correctKeystrokes,
      wrongKeystrokes: _wrongKeystrokes,
      startedAt: startedAt,
      completedAt: completedAt,
      platform: _platformLabel,
    );
    _sessionRecorded = true;
    _sessionStartedAt = null;
    unawaited(_statistics.recordSession(session));
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
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
    final String? pronunciationText = _pronunciationTextFor(word, dict);
    if (pronunciationText == null) {
      return;
    }
    unawaited(_audioService.playPronunciation(
      pronunciationText,
      variant: _pronunciationVariant,
      languageCode: dict.normalizedLanguageCode,
    ));
  }

  void _finishSession() {
    _isFinished = true;
    _isTyping = false;
    _cancelTimer();
    _recordCompletedSession();
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

  String? _pronunciationTextFor(WordEntry word, DictionaryMeta dictionary) {
    final List<String?> candidates = <String?>[];
    // Select pronunciation source based on language capabilities:
    // some providers expect phonetic text (e.g. Japanese notation),
    // while others require the original headword.
    final PronunciationVariant variant = _pronunciationVariant;
    final bool variantsSupported =
        _audioService.supportsPronunciationVariants(dictionary.normalizedLanguageCode);
    final bool preferPhoneticInput =
        _audioService.prefersPhoneticInput(dictionary.normalizedLanguageCode);

    if (preferPhoneticInput) {
      if (variantsSupported) {
        if (variant == PronunciationVariant.us) {
          candidates
            ..add(word.usPhonetic)
            ..add(word.ukPhonetic);
        } else {
          candidates
            ..add(word.ukPhonetic)
            ..add(word.usPhonetic);
        }
      } else {
        candidates
          ..add(word.usPhonetic)
          ..add(word.ukPhonetic);
      }
    }

    candidates.add(word.notation);
    candidates.add(word.headword);

    if (!preferPhoneticInput) {
      candidates
        ..add(word.usPhonetic)
        ..add(word.ukPhonetic);
    }

    final String languageCode = dictionary.normalizedLanguageCode;
    for (final String? candidate in candidates) {
      final String? normalized = _normalizePronunciationCandidate(candidate, languageCode);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _normalizePronunciationCandidate(String? value, String languageCode) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return _audioService.preparePronunciationText(languageCode, trimmed);
  }

  @override
  void dispose() {
    _disposed = true;
    _statistics.removeListener(_handleStatisticsUpdated);
    _cancelTimer();
    super.dispose();
  }
}
