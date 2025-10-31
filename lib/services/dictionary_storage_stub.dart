bool get isSupported => false;

Future<void> ensureInitialized() async {}

Future<List<Map<String, dynamic>>> loadManifest() async => <Map<String, dynamic>>[];

Future<void> saveManifest(List<Map<String, dynamic>> manifest) async {
  throw UnsupportedError('Local dictionary storage is not available on this platform.');
}

Future<String> writeDictionaryFile(String id, List<Map<String, dynamic>> entries) async {
  throw UnsupportedError('Local dictionary storage is not available on this platform.');
}

Future<String> readDictionaryFile(String path) async {
  throw UnsupportedError('Local dictionary storage is not available on this platform.');
}

Future<void> deleteDictionaryFile(String path) async {
  throw UnsupportedError('Local dictionary storage is not available on this platform.');
}

Future<String> readExternalFile(String path) async {
  throw UnsupportedError('Local dictionary storage is not available on this platform.');
}
