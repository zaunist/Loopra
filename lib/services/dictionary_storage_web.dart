import 'dart:convert';

import 'package:web/web.dart' as web;

bool get isSupported => true;

const String _manifestKey = 'loopra.manifest';
const String _dictionaryPrefix = 'loopra.dict.';

web.Storage? _getLocalStorage() {
  try {
    return web.window.localStorage;
  } on Object {
    return null;
  }
}

Future<void> ensureInitialized() async {
  // LocalStorage does not require initialization.
}

Future<List<Map<String, dynamic>>> loadManifest() async {
  final web.Storage? storage = _getLocalStorage();
  final String? raw = storage?.getItem(_manifestKey);
  if (raw == null || raw.trim().isEmpty) {
    return <Map<String, dynamic>>[];
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (Map<dynamic, dynamic> item) => item.map<String, dynamic>(
              (dynamic key, dynamic value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            ),
          )
          .toList();
    }
  } catch (_) {
    // Ignore malformed manifest.
  }
  return <Map<String, dynamic>>[];
}

Future<void> saveManifest(List<Map<String, dynamic>> manifest) async {
  final web.Storage? storage = _getLocalStorage();
  if (storage == null) {
    throw StateError('浏览器不支持本地存储，无法保存词典清单。');
  }
  try {
    storage.setItem(_manifestKey, jsonEncode(manifest));
  } on Object catch (error) {
    throw StateError('无法保存词典清单：$error');
  }
}

Future<String> writeDictionaryFile(
  String id,
  List<Map<String, dynamic>> entries,
) async {
  final String key = _dictionaryPrefix + id;
  final web.Storage? storage = _getLocalStorage();
  if (storage == null) {
    throw StateError('浏览器不支持本地存储，无法保存词典。');
  }
  try {
    storage.setItem(key, jsonEncode(entries));
  } on Object catch (error) {
    throw StateError('存储空间不足或不可用，无法保存词典：$error');
  }
  return key;
}

Future<String> readDictionaryFile(String path) async {
  final web.Storage? storage = _getLocalStorage();
  final String? content = storage?.getItem(path);
  if (content == null) {
    throw StateError('未找到词典数据：$path');
  }
  return content;
}

Future<void> deleteDictionaryFile(String path) async {
  final web.Storage? storage = _getLocalStorage();
  storage?.removeItem(path);
}

Future<String> readExternalFile(String path) async {
  throw UnsupportedError('浏览器环境不支持通过路径读取文件。');
}
