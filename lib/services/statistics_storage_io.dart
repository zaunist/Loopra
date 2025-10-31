import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

File? _statsFile;
bool _initialized = false;

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
  final File statsFile = File('${directory.path}${separator}statistics.json');
  if (!await statsFile.exists()) {
    await statsFile.writeAsString(jsonEncode(_emptyPayload));
  } else if ((await statsFile.length()) == 0) {
    await statsFile.writeAsString(jsonEncode(_emptyPayload));
  }
  _statsFile = statsFile;
  _initialized = true;
}

Future<Map<String, dynamic>> loadStatistics() async {
  await ensureInitialized();
  final File? file = _statsFile;
  if (file == null) {
    return _emptyPayload;
  }
  try {
    final String contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return _emptyPayload;
    }
    final dynamic decoded = jsonDecode(contents);
    if (decoded is Map) {
      return decoded.map<String, dynamic>(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }
  } catch (_) {
    // Ignore malformed payloads and return empty data.
  }
  return _emptyPayload;
}

Future<void> saveStatistics(Map<String, dynamic> data) async {
  await ensureInitialized();
  final File? file = _statsFile;
  if (file == null) {
    return;
  }
  final String payload = jsonEncode(data);
  await file.writeAsString(payload);
}

Map<String, dynamic> get _emptyPayload => <String, dynamic>{
  'version': 1,
  'sessions': <dynamic>[],
};
