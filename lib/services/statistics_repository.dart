import 'package:flutter/foundation.dart';

import '../models/practice_statistics.dart';
import 'remote_statistics_service.dart';
import 'statistics_storage.dart';

typedef UserIdProvider = String? Function();
typedef SyncPermissionProvider = bool Function();

class StatisticsRepository {
  StatisticsRepository({
    required RemoteStatisticsService remoteService,
    required UserIdProvider userIdProvider,
    required SyncPermissionProvider canSyncProvider,
  })  : _remoteService = remoteService,
        _userIdProvider = userIdProvider,
        _canSyncProvider = canSyncProvider;

  final RemoteStatisticsService _remoteService;
  final UserIdProvider _userIdProvider;
  final SyncPermissionProvider _canSyncProvider;

  Future<PracticeStatisticsSnapshot> loadSnapshot() async {
    await StatisticsStorage.ensureInitialized();
    final String profileId = _storageProfileId();
    Map<String, dynamic> raw = await StatisticsStorage.loadStatistics(profileId: profileId);
    PracticeStatisticsSnapshot snapshot = PracticeStatisticsSnapshot.fromJson(raw);

    if (_shouldSync()) {
      final String? userId = _currentUserId();
      if (userId != null && userId.isNotEmpty) {
        try {
          final Map<String, dynamic>? remote = await _remoteService.fetchSnapshot(userId);
          if (remote != null && remote.isNotEmpty) {
            snapshot = PracticeStatisticsSnapshot.fromJson(remote);
            raw = remote;
            await StatisticsStorage.saveStatistics(raw, profileId: profileId);
          } else if (snapshot.sessions.isNotEmpty) {
            await _remoteService.upsertSnapshot(userId, snapshot.toJson());
          }
        } catch (error) {
          debugPrint('远程统计数据加载失败: $error');
        }
      }
    }

    return snapshot;
  }

  Future<void> saveSnapshot(PracticeStatisticsSnapshot snapshot) async {
    await StatisticsStorage.ensureInitialized();
    await StatisticsStorage.saveStatistics(snapshot.toJson(), profileId: _storageProfileId());
    await _syncRemoteSnapshot(snapshot);
  }

  Future<void> _syncRemoteSnapshot(PracticeStatisticsSnapshot snapshot) async {
    if (!_shouldSync()) {
      return;
    }
    final String? userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    try {
      await _remoteService.upsertSnapshot(userId, snapshot.toJson());
    } catch (error) {
      debugPrint('远程统计数据同步失败: $error');
    }
  }

  bool _shouldSync() {
    return _remoteService.isAvailable && _canSyncProvider();
  }

  String _storageProfileId() {
    final String? userId = _currentUserId();
    if (userId == null || userId.trim().isEmpty) {
      return 'anonymous';
    }
    return 'user_${userId.trim()}';
  }

  String? _currentUserId() {
    return _userIdProvider();
  }
}
