import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dictionary.dart';
import '../models/word_entry.dart';
import 'dictionary_storage.dart';

class DictionaryRepository {
  DictionaryRepository();

  static const int chapterLength = 20;
  static const String _manifestPath = 'assets/dicts/manifest.json';

  List<DictionaryMeta> _dictionaries = const <DictionaryMeta>[];
  bool _manifestLoaded = false;

  final Map<String, List<WordEntry>> _cache = <String, List<WordEntry>>{};

  List<DictionaryMeta> get dictionaries => List<DictionaryMeta>.unmodifiable(_dictionaries);

  DictionaryMeta? get defaultDictionary => _dictionaries.isEmpty ? null : _dictionaries.first;

  bool get supportsDictionaryManagement => DictionaryStorage.isSupported;

  Future<List<DictionaryMeta>> loadManifest({bool refresh = false}) async {
    if (refresh) {
      _manifestLoaded = false;
      _dictionaries = const <DictionaryMeta>[];
    }
    if (_manifestLoaded) {
      return List<DictionaryMeta>.unmodifiable(_dictionaries);
    }

    final List<DictionaryMeta> builtIn = await _loadBuiltInManifest();
    final List<DictionaryMeta> custom = await _loadCustomManifest();
    _dictionaries = <DictionaryMeta>[...builtIn, ...custom];
    _manifestLoaded = true;
    return List<DictionaryMeta>.unmodifiable(_dictionaries);
  }

  Future<DictionaryMeta> importDictionary(String jsonContent) async {
    if (!supportsDictionaryManagement) {
      throw UnsupportedError('Custom dictionaries are not supported on this platform.');
    }

    await loadManifest();

    final dynamic decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('词典文件必须是包含 meta 和 entries 字段的 JSON 对象。');
    }

    final dynamic metaRaw = decoded['meta'];
    final dynamic entriesRaw = decoded['entries'] ?? decoded['words'];

    if (metaRaw is! Map<String, dynamic>) {
      throw FormatException('词典文件缺少 meta 字段。');
    }
    if (entriesRaw is! List) {
      throw FormatException('词典文件缺少 entries 列表。');
    }

    final List<Map<String, dynamic>> entries = entriesRaw
        .whereType<Map>()
        .map<Map<String, dynamic>>((Map<dynamic, dynamic> item) => item.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
            ))
        .toList();

    if (entries.isEmpty) {
      throw FormatException('词典 entries 不能为空。');
    }

    String id = (metaRaw['id']?.toString() ?? '').trim();
    if (id.isEmpty) {
      id = _sanitizeId(metaRaw['name']?.toString() ?? 'dictionary');
    } else {
      id = _sanitizeId(id);
    }
    id = _makeUniqueId(id);

    final String rawName = (metaRaw['name']?.toString() ?? '').trim();
    final String name = rawName.isEmpty ? id : rawName;
    final String description = metaRaw['description']?.toString() ?? '';
    final String? category = metaRaw['category']?.toString();
    final String normalizedLanguageCode = (metaRaw['language']?.toString() ?? '').toLowerCase();
    final DictionaryLanguage dictionaryLanguage = DictionaryLanguageX.fromCode(normalizedLanguageCode);

    final String filePath = await DictionaryStorage.writeDictionaryFile(id, entries);

    final DictionaryMeta meta = DictionaryMeta(
      id: id,
      name: name,
      description: description,
      assetPath: filePath,
      language: dictionaryLanguage,
      languageCode: normalizedLanguageCode.isEmpty ? dictionaryLanguage.code : normalizedLanguageCode,
      category: category,
      isCustom: true,
    );

    await _persistCustomMeta(meta);

    _cache.remove(id);
    _manifestLoaded = false;
    await loadManifest(refresh: true);

    return meta;
  }

  Future<void> deleteDictionary(String id) async {
    if (!supportsDictionaryManagement) {
      throw UnsupportedError('Custom dictionaries are not supported on this platform.');
    }
    await loadManifest();

    final DictionaryMeta meta = _dictionaries.firstWhere((DictionaryMeta element) => element.id == id);
    if (!meta.isCustom) {
      throw StateError('内置词典不支持删除。');
    }

    await DictionaryStorage.deleteDictionaryFile(meta.assetPath);

    final List<Map<String, dynamic>> manifest = await DictionaryStorage.loadManifest();
    manifest.removeWhere((Map<String, dynamic> entry) => entry['id']?.toString() == id);
    await DictionaryStorage.saveManifest(manifest);

    _cache.remove(id);
    _manifestLoaded = false;
    await loadManifest(refresh: true);
  }

  Future<String> readExternalFile(String path) async {
    if (!supportsDictionaryManagement) {
      throw UnsupportedError('Custom dictionaries are not supported on this platform.');
    }
    return DictionaryStorage.readExternalFile(path);
  }

  Future<List<WordEntry>> loadWords(String id) async {
    await loadManifest();

    final List<WordEntry>? cached = _cache[id];
    if (cached != null) {
      return cached;
    }

    final DictionaryMeta meta = _dictionaries.firstWhere((DictionaryMeta element) => element.id == id);
    final String jsonString = meta.assetPath.startsWith('assets/')
        ? await rootBundle.loadString(meta.assetPath)
        : await DictionaryStorage.readDictionaryFile(meta.assetPath);

    final List<WordEntry> words = _parseWordEntries(jsonString);

    _cache[id] = words;
    return words;
  }

  Future<List<WordEntry>> loadChapter({required String id, required int chapter}) async {
    await loadManifest();

    final List<WordEntry> allWords = await loadWords(id);
    final int start = chapter * chapterLength;
    if (start >= allWords.length) {
      return const <WordEntry>[];
    }
    final int calculatedEnd = start + chapterLength;
    final int end = calculatedEnd > allWords.length ? allWords.length : calculatedEnd;
    return allWords.sublist(start, end);
  }

  Future<int> chapterCount(String id) async {
    await loadManifest();

    final List<WordEntry> allWords = await loadWords(id);
    return (allWords.length + chapterLength - 1) ~/ chapterLength;
  }

  Future<List<DictionaryMeta>> _loadBuiltInManifest() async {
    try {
      final String jsonString = await rootBundle.loadString(_manifestPath);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map<DictionaryMeta>((Map<dynamic, dynamic> item) => DictionaryMeta.fromJson(
                  item.map<String, dynamic>(
                    (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
                  ),
                ))
            .where((DictionaryMeta meta) => meta.id.isNotEmpty && meta.assetPath.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore malformed manifest and fall back to an empty list.
    }
    return const <DictionaryMeta>[];
  }

  Future<List<DictionaryMeta>> _loadCustomManifest() async {
    if (!supportsDictionaryManagement) {
      return const <DictionaryMeta>[];
    }
    try {
      final List<Map<String, dynamic>> manifest = await DictionaryStorage.loadManifest();
      return manifest
          .map<DictionaryMeta>(DictionaryMeta.fromJson)
          .where((DictionaryMeta meta) => meta.id.isNotEmpty && meta.assetPath.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <DictionaryMeta>[];
    }
  }

  Future<void> _persistCustomMeta(DictionaryMeta meta) async {
    final List<Map<String, dynamic>> manifest = await DictionaryStorage.loadManifest();
    manifest.removeWhere((Map<String, dynamic> entry) => entry['id']?.toString() == meta.id);
    manifest.add(meta.toPersistedJson());
    await DictionaryStorage.saveManifest(manifest);
  }

  String _makeUniqueId(String base) {
    String candidate = base;
    int suffix = 1;
    while (_dictionaries.any((DictionaryMeta meta) => meta.id == candidate)) {
      candidate = '$base-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _sanitizeId(String raw) {
    final String sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();
    if (sanitized.isEmpty) {
      return 'dictionary';
    }
    return sanitized;
  }

  List<WordEntry> _parseWordEntries(String json) {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! List) {
      throw FormatException('词典数据格式错误：应为包含词条的数组。');
    }
    return decoded
        .whereType<Map>()
        .map<WordEntry>((Map<dynamic, dynamic> item) => WordEntry.fromJson(
              item.map<String, dynamic>(
                (dynamic key, dynamic value) => MapEntry<String, dynamic>(key.toString(), value),
              ),
            ))
        .where((WordEntry word) => word.headword.isNotEmpty)
        .toList(growable: false);
  }
}
