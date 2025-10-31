import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

bool get isSupported => true;

Directory? _storageDirectory;
File? _manifestFile;
bool _initialized = false;

Future<void> ensureInitialized() async {
  if (_initialized) {
    return;
  }
  final Directory base = await getApplicationSupportDirectory();
  final Directory directory = Directory('${base.path}${Platform.pathSeparator}dictionaries');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final File manifest = File('${directory.path}${Platform.pathSeparator}manifest.json');
  if (!await manifest.exists()) {
    await manifest.writeAsString('[]');
  }
  _storageDirectory = directory;
  _manifestFile = manifest;
  _initialized = true;
}

Future<List<Map<String, dynamic>>> loadManifest() async {
  await ensureInitialized();
  final File? manifest = _manifestFile;
  if (manifest == null) {
    return <Map<String, dynamic>>[];
  }
  try {
    final String raw = await manifest.readAsString();
    if (raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final dynamic decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map<Map<String, dynamic>>((Map<dynamic, dynamic> item) => item.map<String, dynamic>(
                (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
              ))
          .toList();
    }
  } catch (_) {
    // Ignore malformed manifest and restart.
  }
  return <Map<String, dynamic>>[];
}

Future<void> saveManifest(List<Map<String, dynamic>> manifest) async {
  await ensureInitialized();
  final File? manifestFile = _manifestFile;
  if (manifestFile == null) {
    return;
  }
  final String encoded = jsonEncode(manifest);
  await manifestFile.writeAsString(encoded);
}

Future<String> writeDictionaryFile(String id, List<Map<String, dynamic>> entries) async {
  await ensureInitialized();
  final Directory? directory = _storageDirectory;
  if (directory == null) {
    throw StateError('Dictionary storage directory is not available.');
  }
  final String sanitized = _sanitizeId(id);
  File candidate = File('${directory.path}${Platform.pathSeparator}$sanitized.json');
  int counter = 1;
  while (await candidate.exists()) {
    candidate = File('${directory.path}${Platform.pathSeparator}$sanitized-$counter.json');
    counter += 1;
  }
  await candidate.writeAsString(jsonEncode(entries));
  return candidate.path;
}

Future<String> readDictionaryFile(String path) async {
  final File file = File(path);
  return file.readAsString();
}

Future<void> deleteDictionaryFile(String path) async {
  final File file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<String> readExternalFile(String path) async {
  final File file = File(path);
  return file.readAsString();
}

String _sanitizeId(String raw) {
  final String sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  if (sanitized.isEmpty) {
    return 'dictionary';
  }
  return sanitized.toLowerCase();
}
