Future<void> ensureInitialized() async {}

Future<Map<String, dynamic>> loadStatistics() async => <String, dynamic>{};

Future<void> saveStatistics(Map<String, dynamic> data) async {
  throw UnsupportedError('Statistics persistence is not available on this platform.');
}
