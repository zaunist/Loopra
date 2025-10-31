class DictionaryMeta {
  const DictionaryMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    this.language = DictionaryLanguage.english,
    this.category,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String description;
  final String assetPath;
  final DictionaryLanguage language;
  final String? category;
  final bool isCustom;

  factory DictionaryMeta.fromJson(Map<String, dynamic> json) {
    final String asset = json['asset']?.toString() ?? '';
    final bool isCustom = json['custom'] == true || json['isCustom'] == true;
    return DictionaryMeta(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      assetPath: _normalizeAssetPath(asset, isCustom: isCustom),
      language: DictionaryLanguageX.fromCode(json['language']?.toString()),
      category: json['category']?.toString(),
      isCustom: isCustom,
    );
  }

  Map<String, dynamic> toPersistedJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'asset': assetPath,
      'language': language.code,
      'category': category,
      'custom': isCustom,
    };
  }
}

String _normalizeAssetPath(String asset, {required bool isCustom}) {
  if (asset.isEmpty) {
    return '';
  }
  final String normalized = asset.replaceFirst(RegExp(r'^file://'), '');
  if (isCustom) {
    return normalized;
  }
  final bool isAbsolutePath =
      normalized.startsWith('/') || normalized.contains(':/') || normalized.contains(':\\');
  if (normalized.startsWith('assets/')) {
    return normalized;
  }
  if (isAbsolutePath) {
    return normalized;
  }
  return 'assets/dicts/$normalized';
}

enum DictionaryLanguage {
  english,
  code,
  other,
}

extension DictionaryLanguageX on DictionaryLanguage {
  static DictionaryLanguage fromCode(String? code) {
    switch (code) {
      case 'en':
        return DictionaryLanguage.english;
      case 'code':
        return DictionaryLanguage.code;
      default:
        return DictionaryLanguage.other;
    }
  }

  String get code {
    switch (this) {
      case DictionaryLanguage.english:
        return 'en';
      case DictionaryLanguage.code:
        return 'code';
      case DictionaryLanguage.other:
        return 'other';
    }
  }
}
