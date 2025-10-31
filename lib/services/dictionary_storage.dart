import 'dictionary_storage_stub.dart'
    if (dart.library.io) 'dictionary_storage_io.dart'
    if (dart.library.html) 'dictionary_storage_web.dart' as impl;

class DictionaryStorage {
  const DictionaryStorage._();

  static bool get isSupported => impl.isSupported;

  static Future<void> ensureInitialized() => impl.ensureInitialized();

  static Future<List<Map<String, dynamic>>> loadManifest() => impl.loadManifest();

  static Future<void> saveManifest(List<Map<String, dynamic>> manifest) => impl.saveManifest(manifest);

  static Future<String> writeDictionaryFile(String id, List<Map<String, dynamic>> entries) =>
      impl.writeDictionaryFile(id, entries);

  static Future<String> readDictionaryFile(String path) => impl.readDictionaryFile(path);

  static Future<void> deleteDictionaryFile(String path) => impl.deleteDictionaryFile(path);

  static Future<String> readExternalFile(String path) => impl.readExternalFile(path);
}
