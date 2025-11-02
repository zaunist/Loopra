import 'dart:convert';

import 'package:web/web.dart' as web;

const String _storageKeyPrefix = 'loopra.practice_statistics';

Future<void> ensureInitialized() async {
  // No-op for localStorage-backed storage.
}

Future<Map<String, dynamic>> loadStatistics(String profileId) async {
  final web.Storage? storage = _getStorage();
  if (storage == null) {
    return _emptyPayload;
  }
  final String? raw = storage.getItem(_buildKey(profileId));
  if (raw == null || raw.trim().isEmpty) {
    return _emptyPayload;
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
      );
    }
  } catch (_) {
    // Ignore malformed payloads.
  }
  return _emptyPayload;
}

Future<void> saveStatistics(String profileId, Map<String, dynamic> data) async {
  final web.Storage? storage = _getStorage();
  if (storage == null) {
    throw StateError('当前浏览器不支持本地存储，无法保存练习统计数据。');
  }
  storage.setItem(_buildKey(profileId), jsonEncode(data));
}

String _buildKey(String profileId) => '$_storageKeyPrefix::$profileId';

web.Storage? _getStorage() {
  try {
    return web.window.localStorage;
  } on Object {
    return null;
  }
}

Map<String, dynamic> get _emptyPayload => <String, dynamic>{
      'version': 1,
      'sessions': <dynamic>[],
    };
