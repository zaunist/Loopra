import 'dart:math';

/// Represents a single practice session that can be synchronised across devices.
class PracticeSessionRecord {
  const PracticeSessionRecord({
    required this.id,
    required this.dictionaryId,
    required this.dictionaryName,
    required this.chapterIndex,
    required this.totalWords,
    required this.completedWords,
    required this.elapsedSeconds,
    required this.correctKeystrokes,
    required this.wrongKeystrokes,
    required this.startedAt,
    required this.completedAt,
    this.platform,
    this.appVersion,
  });

  final String id;
  final String dictionaryId;
  final String dictionaryName;
  final int chapterIndex;
  final int totalWords;
  final int completedWords;
  final int elapsedSeconds;
  final int correctKeystrokes;
  final int wrongKeystrokes;
  final DateTime startedAt;
  final DateTime completedAt;
  final String? platform;
  final String? appVersion;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'dictionaryId': dictionaryId,
      'dictionaryName': dictionaryName,
      'chapterIndex': chapterIndex,
      'totalWords': totalWords,
      'completedWords': completedWords,
      'elapsedSeconds': elapsedSeconds,
      'correctKeystrokes': correctKeystrokes,
      'wrongKeystrokes': wrongKeystrokes,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  factory PracticeSessionRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw) {
      if (raw is DateTime) {
        return raw;
      }
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return PracticeSessionRecord(
      id: json['id']?.toString() ?? '',
      dictionaryId: json['dictionaryId']?.toString() ?? '',
      dictionaryName: json['dictionaryName']?.toString() ?? '',
      chapterIndex: json['chapterIndex'] is int
          ? json['chapterIndex'] as int
          : int.tryParse(json['chapterIndex']?.toString() ?? '') ?? 0,
      totalWords: json['totalWords'] is int
          ? json['totalWords'] as int
          : int.tryParse(json['totalWords']?.toString() ?? '') ?? 0,
      completedWords: json['completedWords'] is int
          ? json['completedWords'] as int
          : int.tryParse(json['completedWords']?.toString() ?? '') ?? 0,
      elapsedSeconds: json['elapsedSeconds'] is int
          ? json['elapsedSeconds'] as int
          : int.tryParse(json['elapsedSeconds']?.toString() ?? '') ?? 0,
      correctKeystrokes: json['correctKeystrokes'] is int
          ? json['correctKeystrokes'] as int
          : int.tryParse(json['correctKeystrokes']?.toString() ?? '') ?? 0,
      wrongKeystrokes: json['wrongKeystrokes'] is int
          ? json['wrongKeystrokes'] as int
          : int.tryParse(json['wrongKeystrokes']?.toString() ?? '') ?? 0,
      startedAt: parseDate(json['startedAt']),
      completedAt: parseDate(json['completedAt']),
      platform: json['platform']?.toString(),
      appVersion: json['appVersion']?.toString(),
    );
  }

  double get accuracy {
    final int total = correctKeystrokes + wrongKeystrokes;
    if (total == 0) {
      return 1;
    }
    return correctKeystrokes / total;
  }

  double get completionRate {
    if (totalWords == 0) {
      return 0;
    }
    return completedWords / totalWords;
  }

  double get wordsPerMinute {
    if (elapsedSeconds <= 0) {
      return 0;
    }
    return (completedWords / elapsedSeconds) * 60;
  }
}

/// Snapshot of all practice statistics that can be persisted locally or remotely.
class PracticeStatisticsSnapshot {
  const PracticeStatisticsSnapshot({
    required this.version,
    required this.sessions,
  });

  static const int currentVersion = 1;

  final int version;
  final List<PracticeSessionRecord> sessions;

  factory PracticeStatisticsSnapshot.empty() {
    return const PracticeStatisticsSnapshot(
      version: currentVersion,
      sessions: <PracticeSessionRecord>[],
    );
  }

  factory PracticeStatisticsSnapshot.fromJson(Map<String, dynamic> json) {
    final int version = json['version'] is int
        ? json['version'] as int
        : int.tryParse(json['version']?.toString() ?? '') ?? currentVersion;
    final dynamic rawSessions = json['sessions'];
    final List<PracticeSessionRecord> sessions = rawSessions is List
        ? rawSessions
            .whereType<Map>()
            .map<Map<String, dynamic>>(
              (Map<dynamic, dynamic> item) => item.map<String, dynamic>(
                (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
              ),
            )
            .map<PracticeSessionRecord>(PracticeSessionRecord.fromJson)
            .where((PracticeSessionRecord session) => session.id.isNotEmpty)
            .toList(growable: false)
        : const <PracticeSessionRecord>[];
    return PracticeStatisticsSnapshot(version: version, sessions: sessions);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'sessions': sessions.map((PracticeSessionRecord session) => session.toJson()).toList(),
    };
  }

  PracticeStatisticsSnapshot appendSession(PracticeSessionRecord session) {
    final List<PracticeSessionRecord> updated = List<PracticeSessionRecord>.from(sessions)
      ..add(session);
    updated.sort((PracticeSessionRecord a, PracticeSessionRecord b) => a.completedAt.compareTo(b.completedAt));
    return PracticeStatisticsSnapshot(
      version: max(version, currentVersion),
      sessions: List<PracticeSessionRecord>.unmodifiable(updated),
    );
  }

  PracticeTotals get totals => totalsForDictionary(null);

  PracticeTotals totalsForDictionary(String? dictionaryId) {
    final List<PracticeSessionRecord> filtered = dictionaryId == null
        ? List<PracticeSessionRecord>.from(sessions)
        : sessions.where((PracticeSessionRecord session) => session.dictionaryId == dictionaryId).toList();
    return _calculateTotals(filtered);
  }

  PracticeTotals _calculateTotals(List<PracticeSessionRecord> entries) {
    int totalSeconds = 0;
    int totalWords = 0;
    int totalCorrect = 0;
    int totalWrong = 0;

    for (final PracticeSessionRecord session in entries) {
      totalSeconds += session.elapsedSeconds;
      totalWords += session.completedWords;
      totalCorrect += session.correctKeystrokes;
      totalWrong += session.wrongKeystrokes;
    }

    final int totalKeystrokes = totalCorrect + totalWrong;
    final double accuracy = totalKeystrokes == 0 ? 1 : totalCorrect / totalKeystrokes;
    final double wordsPerMinute =
        totalSeconds == 0 ? 0 : (totalWords / totalSeconds) * 60;

    return PracticeTotals(
      totalSessions: entries.length,
      totalCompletedWords: totalWords,
      totalElapsedSeconds: totalSeconds,
      accuracy: accuracy,
      averageWordsPerMinute: wordsPerMinute,
    );
  }

  List<ChapterStatisticsSummary> buildChapterSummaries({String? dictionaryId}) {
    final List<PracticeSessionRecord> filtered = dictionaryId == null
        ? List<PracticeSessionRecord>.from(sessions)
        : sessions.where((PracticeSessionRecord session) => session.dictionaryId == dictionaryId).toList();
    if (filtered.isEmpty) {
      return const <ChapterStatisticsSummary>[];
    }

    final Map<String, List<PracticeSessionRecord>> grouped = <String, List<PracticeSessionRecord>>{};
    for (final PracticeSessionRecord session in filtered) {
      final String key = '${session.dictionaryId}#${session.chapterIndex}';
      final List<PracticeSessionRecord> list =
          grouped.putIfAbsent(key, () => <PracticeSessionRecord>[]);
      list.add(session);
    }

    final List<ChapterStatisticsSummary> summaries = <ChapterStatisticsSummary>[];
    grouped.forEach((String _, List<PracticeSessionRecord> items) {
      if (items.isEmpty) {
        return;
      }
      summaries.add(ChapterStatisticsSummary.fromSessions(items));
    });

    summaries.sort(
      (ChapterStatisticsSummary a, ChapterStatisticsSummary b) {
        final int dictionaryCompare = a.dictionaryName.compareTo(b.dictionaryName);
        if (dictionaryCompare != 0) {
          return dictionaryCompare;
        }
        if (a.chapterIndex != b.chapterIndex) {
          return a.chapterIndex.compareTo(b.chapterIndex);
        }
        return a.lastPracticed.compareTo(b.lastPracticed);
      },
    );

    return summaries;
  }

  List<PracticeDictionaryRef> get availableDictionaries {
    if (sessions.isEmpty) {
      return const <PracticeDictionaryRef>[];
    }
    final Map<String, PracticeDictionaryRef> map = <String, PracticeDictionaryRef>{};
    for (final PracticeSessionRecord session in sessions.reversed) {
      if (session.dictionaryId.isEmpty) {
        continue;
      }
      map.putIfAbsent(
        session.dictionaryId,
        () => PracticeDictionaryRef(id: session.dictionaryId, name: session.dictionaryName),
      );
    }
    final List<PracticeDictionaryRef> dictionaries = map.values.toList(growable: false);
    dictionaries.sort(
      (PracticeDictionaryRef a, PracticeDictionaryRef b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return dictionaries;
  }
}

class PracticeTotals {
  const PracticeTotals({
    required this.totalSessions,
    required this.totalCompletedWords,
    required this.totalElapsedSeconds,
    required this.accuracy,
    required this.averageWordsPerMinute,
  });

  final int totalSessions;
  final int totalCompletedWords;
  final int totalElapsedSeconds;
  final double accuracy;
  final double averageWordsPerMinute;
}

class ChapterStatisticsSummary {
  const ChapterStatisticsSummary({
    required this.dictionaryId,
    required this.dictionaryName,
    required this.chapterIndex,
    required this.sessionCount,
    required this.averageCompletionRate,
    required this.averageAccuracy,
    required this.averageWordsPerMinute,
    required this.averageElapsedSeconds,
    required this.totalCompletedWords,
    required this.lastPracticed,
  });

  final String dictionaryId;
  final String dictionaryName;
  final int chapterIndex;
  final int sessionCount;
  final double averageCompletionRate;
  final double averageAccuracy;
  final double averageWordsPerMinute;
  final double averageElapsedSeconds;
  final int totalCompletedWords;
  final DateTime lastPracticed;

  factory ChapterStatisticsSummary.fromSessions(List<PracticeSessionRecord> sessions) {
    if (sessions.isEmpty) {
      throw ArgumentError('sessions must not be empty');
    }
    sessions.sort(
      (PracticeSessionRecord a, PracticeSessionRecord b) => a.completedAt.compareTo(b.completedAt),
    );

    double completionSum = 0;
    double accuracySum = 0;
    double wpmSum = 0;
    double elapsedSum = 0;
    int totalCompletedWords = 0;
    DateTime latest = sessions.first.completedAt;

    for (final PracticeSessionRecord session in sessions) {
      completionSum += session.completionRate;
      accuracySum += session.accuracy;
      wpmSum += session.wordsPerMinute;
      elapsedSum += session.elapsedSeconds.toDouble();
      totalCompletedWords += session.completedWords;
      if (session.completedAt.isAfter(latest)) {
        latest = session.completedAt;
      }
    }

    final int count = sessions.length;
    final PracticeSessionRecord base = sessions.last;

    return ChapterStatisticsSummary(
      dictionaryId: base.dictionaryId,
      dictionaryName: base.dictionaryName,
      chapterIndex: base.chapterIndex,
      sessionCount: count,
      averageCompletionRate: count == 0 ? 0 : completionSum / count,
      averageAccuracy: count == 0 ? 0 : accuracySum / count,
      averageWordsPerMinute: count == 0 ? 0 : wpmSum / count,
      averageElapsedSeconds: count == 0 ? 0 : elapsedSum / count,
      totalCompletedWords: totalCompletedWords,
      lastPracticed: latest,
    );
  }
}

class PracticeDictionaryRef {
  const PracticeDictionaryRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
