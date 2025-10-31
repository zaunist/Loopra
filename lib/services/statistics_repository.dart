import '../models/practice_statistics.dart';
import 'statistics_storage.dart';

class StatisticsRepository {
  const StatisticsRepository();

  Future<PracticeStatisticsSnapshot> loadSnapshot() async {
    await StatisticsStorage.ensureInitialized();
    final Map<String, dynamic> raw = await StatisticsStorage.loadStatistics();
    return PracticeStatisticsSnapshot.fromJson(raw);
  }

  Future<void> saveSnapshot(PracticeStatisticsSnapshot snapshot) async {
    await StatisticsStorage.ensureInitialized();
    await StatisticsStorage.saveStatistics(snapshot.toJson());
  }
}
