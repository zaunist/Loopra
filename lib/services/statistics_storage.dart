import 'statistics_storage_stub.dart'
    if (dart.library.io) 'statistics_storage_io.dart'
    if (dart.library.html) 'statistics_storage_web.dart' as impl;

class StatisticsStorage {
  const StatisticsStorage._();

  static Future<void> ensureInitialized() => impl.ensureInitialized();

  static Future<Map<String, dynamic>> loadStatistics() => impl.loadStatistics();

  static Future<void> saveStatistics(Map<String, dynamic> data) => impl.saveStatistics(data);
}
