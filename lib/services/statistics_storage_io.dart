import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Directory? _baseDirectory;
bool _initialized = false;
final Map<String, File> _profileFiles = <String, File>{};

Future<void> ensureInitialized() async {
  if (_initialized) {
    return;
  }
  final Directory base = await getApplicationSupportDirectory();
  final String separator = Platform.pathSeparator;
  final Directory directory = Directory('${base.path}${separator}analytics');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  _baseDirectory = directory;
  _initialized = true;
}

Future<Map<String, dynamic>> loadStatistics(String profileId) async {
  final File file = await _ensureProfileFile(profileId);
  try {
    final String contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return _emptyPayload;
    }
    final dynamic decoded = jsonDecode(contents);
    if (decoded is Map) {
      return decoded.map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
      );
    }
  } catch (_) {
    // Ignore malformed payloads and return empty data.
  }
  return _emptyPayload;
}

Future<void> saveStatistics(String profileId, Map<String, dynamic> data) async {
  final File file = await _ensureProfileFile(profileId);
  final String payload = jsonEncode(data);
  await file.writeAsString(payload);
}

Future<void> clearStatistics(String profileId) async {
  final File file = await _ensureProfileFile(profileId);
  await file.writeAsString(jsonEncode(_emptyPayload));
}

Future<File> _ensureProfileFile(String profileId) async {
  await ensureInitialized();
  final Directory? directory = _baseDirectory;
  if (directory == null) {
    throw StateError('Statistics storage directory unavailable.');
  }
  final File? existing = _profileFiles[profileId];
  if (existing != null) {
    return existing;
  }
  final String sanitized = _sanitizeProfile(profileId);
  final String separator = Platform.pathSeparator;
  final File file = File('${directory.path}${separator}statistics_$sanitized.json');
  if (!await file.exists() || (await file.length()) == 0) {
    await file.writeAsString(jsonEncode(_emptyPayload));
  }
  _profileFiles[profileId] = file;
  return file;
}

String _sanitizeProfile(String profileId) {
  if (profileId.isEmpty) {
    return 'anonymous';
  }
  final String sanitized = profileId.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  return sanitized.isEmpty ? 'anonymous' : sanitized;
}

Map<String, dynamic> get _emptyPayload => <String, dynamic>{
      'version': 1,
      'sessions': <dynamic>[],
    };
