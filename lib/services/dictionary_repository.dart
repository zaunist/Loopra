import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dictionary.dart';
import '../models/word_entry.dart';

class DictionaryRepository {
  DictionaryRepository();

  static const int chapterLength = 20;
  static const String _manifestPath = 'assets/dicts/manifest.json';

  List<DictionaryMeta> _dictionaries = const <DictionaryMeta>[];
  bool _manifestLoaded = false;

  final Map<String, List<WordEntry>> _cache = <String, List<WordEntry>>{};

  List<DictionaryMeta> get dictionaries => List<DictionaryMeta>.unmodifiable(_dictionaries);

  DictionaryMeta? get defaultDictionary => _dictionaries.isEmpty ? null : _dictionaries.first;

  Future<List<DictionaryMeta>> loadManifest() async {
    if (_manifestLoaded) {
      return List<DictionaryMeta>.unmodifiable(_dictionaries);
    }

    final String jsonString = await rootBundle.loadString(_manifestPath);
    final List<dynamic> rawList = jsonDecode(jsonString) as List<dynamic>;
    final List<DictionaryMeta> parsed = rawList
        .whereType<Map<String, dynamic>>()
        .map<DictionaryMeta>(DictionaryMeta.fromJson)
        .where((DictionaryMeta meta) => meta.id.isNotEmpty && meta.assetPath.isNotEmpty)
        .toList(growable: false);

    _dictionaries = parsed;
    _manifestLoaded = true;
    return List<DictionaryMeta>.unmodifiable(_dictionaries);
  }

  Future<List<WordEntry>> loadWords(String id) async {
    await loadManifest();

    final List<WordEntry>? cached = _cache[id];
    if (cached != null) {
      return cached;
    }

    final DictionaryMeta meta = _dictionaries.firstWhere((DictionaryMeta element) => element.id == id);
    final String jsonString = await rootBundle.loadString(meta.assetPath);
    final List<dynamic> rawList = jsonDecode(jsonString) as List<dynamic>;
    final List<WordEntry> words = rawList
        .whereType<Map<String, dynamic>>()
        .map<WordEntry>(WordEntry.fromJson)
        .where((WordEntry word) => word.headword.isNotEmpty)
        .toList(growable: false);

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
}
