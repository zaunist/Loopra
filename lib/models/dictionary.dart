class DictionaryMeta {
  const DictionaryMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    this.language = DictionaryLanguage.english,
    this.category,
  });

  final String id;
  final String name;
  final String description;
  final String assetPath;
  final DictionaryLanguage language;
  final String? category;

  factory DictionaryMeta.fromJson(Map<String, dynamic> json) {
    final String asset = json['asset']?.toString() ?? '';
    return DictionaryMeta(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      assetPath: asset.contains('assets/')
          ? asset
          : asset.isEmpty
              ? ''
              : 'assets/dicts/$asset',
      language: DictionaryLanguageX.fromCode(json['language']?.toString()),
      category: json['category']?.toString(),
    );
  }
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
}
