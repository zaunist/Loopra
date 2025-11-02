import 'statistics_storage_stub.dart'
    if (dart.library.io) 'statistics_storage_io.dart'
    if (dart.library.html) 'statistics_storage_web.dart' as impl;

class StatisticsStorage {
  const StatisticsStorage._();

  static Future<void> ensureInitialized() => impl.ensureInitialized();

  static Future<Map<String, dynamic>> loadStatistics({String? profileId}) =>
      impl.loadStatistics(_normaliseProfileId(profileId));

  static Future<void> saveStatistics(Map<String, dynamic> data, {String? profileId}) =>
      impl.saveStatistics(_normaliseProfileId(profileId), data);

  static Future<void> clearStatistics({String? profileId}) =>
      impl.clearStatistics(_normaliseProfileId(profileId));

  static String _normaliseProfileId(String? raw) {
    final String trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'anonymous';
    }
    final String normalised = trimmed.toLowerCase();
    return normalised.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }
}
