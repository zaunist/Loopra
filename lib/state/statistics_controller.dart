import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/practice_statistics.dart';
import '../services/statistics_repository.dart';

class StatisticsController extends ChangeNotifier {
  StatisticsController(this._repository);

  final StatisticsRepository _repository;

  PracticeStatisticsSnapshot _snapshot = PracticeStatisticsSnapshot.empty();
  bool _isLoading = false;
  bool _isInitialized = false;
  Future<void>? _pendingLoad;
  Future<void>? _pendingSave;

  PracticeStatisticsSnapshot get snapshot => _snapshot;

  PracticeTotals get totals => _snapshot.totals;

  List<ChapterStatisticsSummary> get chapterSummaries => _snapshot.buildChapterSummaries();

  List<PracticeSessionRecord> get sessions => List<PracticeSessionRecord>.unmodifiable(_snapshot.sessions);

  List<PracticeDictionaryRef> get dictionaries => _snapshot.availableDictionaries;

  PracticeTotals totalsForDictionary(String? dictionaryId) => _snapshot.totalsForDictionary(dictionaryId);

  List<ChapterStatisticsSummary> chapterSummariesForDictionary(String? dictionaryId) =>
      _snapshot.buildChapterSummaries(dictionaryId: dictionaryId);

  bool get isLoading => _isLoading;

  bool get isReady => _isInitialized && !_isLoading;

  Future<void> initialise() async {
    if (_isInitialized) {
      return _pendingLoad;
    }
    _isLoading = true;
    notifyListeners();

    final Future<void> load = _repository.loadSnapshot().then((PracticeStatisticsSnapshot snapshot) {
      _snapshot = snapshot;
      _isInitialized = true;
    }).whenComplete(() {
      _isLoading = false;
      _pendingLoad = null;
      notifyListeners();
    });
    _pendingLoad = load;
    await load;
  }

  Future<void> recordSession(PracticeSessionRecord session) async {
    await initialise();
    _snapshot = _snapshot.appendSession(session);
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_pendingSave != null) {
      return;
    }
    _pendingSave = _repository.saveSnapshot(_snapshot).whenComplete(() {
      _pendingSave = null;
    });
  }
}
