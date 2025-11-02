import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/practice_statistics.dart';
import '../services/statistics_repository.dart';
import 'auth_controller.dart';
import 'subscription_controller.dart';

class StatisticsController extends ChangeNotifier {
  StatisticsController(
    this._repository, {
    AuthController? authController,
    SubscriptionController? subscriptionController,
  })  : _authController = authController,
        _subscriptionController = subscriptionController {
    _authController?.addListener(_handleSyncDependenciesChanged);
    _subscriptionController?.addListener(_handleSyncDependenciesChanged);
    _syncAvailable = _canSyncRemotely;
  }

  final StatisticsRepository _repository;
  final AuthController? _authController;
  final SubscriptionController? _subscriptionController;

  PracticeStatisticsSnapshot _snapshot = PracticeStatisticsSnapshot.empty();
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _syncAvailable = false;
  String? _lastLoadedUserId;
  Future<void>? _pendingLoad;
  Future<void>? _pendingSave;

  PracticeStatisticsSnapshot get snapshot => _snapshot;

  PracticeTotals get totals => _snapshot.totals;

  List<ChapterStatisticsSummary> get chapterSummaries => _snapshot.buildChapterSummaries();

  List<PracticeSessionRecord> get sessions => List<PracticeSessionRecord>.unmodifiable(_snapshot.sessions);

  List<PracticeDictionaryRef> get dictionaries => _snapshot.availableDictionaries;

  PracticeSessionRecord? get latestSession =>
      _snapshot.sessions.isNotEmpty ? _snapshot.sessions.last : null;

  PracticeTotals totalsForDictionary(String? dictionaryId) => _snapshot.totalsForDictionary(dictionaryId);

  List<ChapterStatisticsSummary> chapterSummariesForDictionary(String? dictionaryId) =>
      _snapshot.buildChapterSummaries(dictionaryId: dictionaryId);

  bool get isLoading => _isLoading;

  bool get isReady => _isInitialized && !_isLoading;

  Future<void> initialise() async {
    if (_isInitialized) {
      return _pendingLoad;
    }
    await _queueLoad();
  }

  Future<void> reload() {
    return _queueLoad(force: true);
  }

  Future<void> recordSession(PracticeSessionRecord session) async {
    await initialise();
    _snapshot = _snapshot.appendSession(session);
    notifyListeners();
    _scheduleSave();
  }

  bool get _canSyncRemotely {
    final bool loggedIn = _authController?.isLoggedIn ?? false;
    final bool subscriptionReady = _subscriptionController?.canSync ?? false;
    return loggedIn && subscriptionReady;
  }

  Future<void> _queueLoad({bool force = false}) {
    if (_pendingLoad != null) {
      return _pendingLoad!;
    }
    if (!force && _isInitialized && !_shouldRefreshForCurrentUser) {
      return Future<void>.value();
    }

    _isLoading = true;
    notifyListeners();

    final Future<void> load = _repository.loadSnapshot().then((PracticeStatisticsSnapshot snapshot) {
      _snapshot = snapshot;
      _isInitialized = true;
      _lastLoadedUserId = _authController?.user?.id;
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('统计数据加载失败: $error');
      throw error;
    }).whenComplete(() {
      _isLoading = false;
      _pendingLoad = null;
      _syncAvailable = _canSyncRemotely;
      notifyListeners();
    });
    _pendingLoad = load;
    return load;
  }

  bool get _shouldRefreshForCurrentUser {
    final String? currentUserId = _authController?.user?.id;
    if (!_canSyncRemotely) {
      return false;
    }
    if (_lastLoadedUserId == null && currentUserId != null) {
      return true;
    }
    return currentUserId != null && currentUserId != _lastLoadedUserId;
  }

  void _scheduleSave() {
    if (_pendingSave != null) {
      return;
    }
    _pendingSave = _repository.saveSnapshot(_snapshot).whenComplete(() {
      _pendingSave = null;
    });
  }

  void _handleSyncDependenciesChanged() {
    final bool canSync = _canSyncRemotely;
    final bool userChanged = _authController?.user?.id != _lastLoadedUserId;
    final bool becameAvailable = canSync && (!_syncAvailable || userChanged);
    if (becameAvailable) {
      unawaited(reload());
    }
    _syncAvailable = canSync;
    if (!canSync) {
      _lastLoadedUserId = _authController?.user?.id;
    }
  }

  @override
  void dispose() {
    _authController?.removeListener(_handleSyncDependenciesChanged);
    _subscriptionController?.removeListener(_handleSyncDependenciesChanged);
    super.dispose();
  }
}
