import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// 同步统计数据到 Supabase 数据表 `typing_statistics`。
/// 预期的数据表包含 `user_id uuid` (主键) 与 `data jsonb` 字段。
class RemoteStatisticsService {
  RemoteStatisticsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  SupabaseClient get _clientOrThrow {
    final SupabaseClient? client = _client;
    if (client == null) {
      throw StateError('Supabase client 未初始化。');
    }
    return client;
  }

  Future<Map<String, dynamic>?> fetchSnapshot(String userId) async {
    if (!isAvailable) {
      return null;
    }
    final SupabaseClient client = _clientOrThrow;
    final Map<String, dynamic>? record =
        await client.from('typing_statistics').select('data').eq('user_id', userId).maybeSingle();
    if (record == null) {
      return null;
    }
    final dynamic data = record['data'];
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> upsertSnapshot(String userId, Map<String, dynamic> data) async {
    if (!isAvailable) {
      return;
    }
    final SupabaseClient client = _clientOrThrow;
    await client.from('typing_statistics').upsert(<String, dynamic>{
      'user_id': userId,
      'data': data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
