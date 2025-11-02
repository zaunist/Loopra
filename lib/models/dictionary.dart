class DictionaryMeta {
  const DictionaryMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    this.language = DictionaryLanguage.english,
    this.languageCode = 'other',
    this.category,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String description;
  final String assetPath;
  final DictionaryLanguage language;
  final String languageCode;
  final String? category;
  final bool isCustom;

  factory DictionaryMeta.fromJson(Map<String, dynamic> json) {
    final String asset = json['asset']?.toString() ?? '';
    final bool isCustom = json['custom'] == true || json['isCustom'] == true;
    final String rawLanguage = (json['language']?.toString() ?? '').toLowerCase();
    final DictionaryLanguage language = DictionaryLanguageX.fromCode(rawLanguage);
    return DictionaryMeta(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      assetPath: _normalizeAssetPath(asset, isCustom: isCustom),
      language: language,
      languageCode: rawLanguage.isEmpty ? language.code : rawLanguage,
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
      'language': languageCode.isEmpty ? language.code : languageCode,
      'category': category,
      'custom': isCustom,
    };
  }

  String get languageLabel => DictionaryLanguageX.displayNameFromCode(languageCode);

  String get normalizedLanguageCode {
    final String code = languageCode.isEmpty ? language.code : languageCode;
    return code.toLowerCase();
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
    switch (code?.toLowerCase()) {
      case 'en':
        return DictionaryLanguage.english;
      case 'code':
        return DictionaryLanguage.code;
      case 'ja':
      case 'zh':
      case 'ko':
      case 'fr':
      case 'de':
      case 'es':
      case 'other':
      case null:
        return DictionaryLanguage.other;
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

  static String displayNameFromCode(String? code) {
    final String normalized = (code ?? '').toLowerCase();
    switch (normalized) {
      case 'en':
        return '英语';
      case 'ja':
        return '日语';
      case 'zh':
        return '中文';
      case 'code':
        return '编程';
      case 'other':
        return '其他语言';
      case 'de':
        return '德语';
      case 'fr':
        return '法语';
      case 'es':
        return '西班牙语';
      case 'ko':
        return '韩语';
      case 'kk':
        return '哈萨克语';
      case 'id':
        return '印尼语';
      case '':
        return '未标注';
      default:
        return normalized.toUpperCase();
    }
  }

  String get displayName => displayNameFromCode(code);
}
