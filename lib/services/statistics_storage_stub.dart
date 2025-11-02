Future<void> ensureInitialized() async {}

Future<Map<String, dynamic>> loadStatistics(String profileId) async => <String, dynamic>{
      'version': 1,
      'sessions': <dynamic>[],
    };

Future<void> saveStatistics(String profileId, Map<String, dynamic> data) async {
  throw UnsupportedError('Statistics persistence is not available on this platform.');
}

Future<void> clearStatistics(String profileId) async {}
