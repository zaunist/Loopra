class WordEntry {
  WordEntry({
    required this.headword,
    required this.translations,
    this.usPhonetic,
    this.ukPhonetic,
    this.notation,
  });

  final String headword;
  final List<String> translations;
  final String? usPhonetic;
  final String? ukPhonetic;
  final String? notation;

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    final dynamic rawTrans = json['trans'];
    final List<String> normalizedTranslations;
    if (rawTrans is List) {
      normalizedTranslations = rawTrans.whereType<String>().toList();
    } else if (rawTrans == null) {
      normalizedTranslations = const [];
    } else {
      normalizedTranslations = [rawTrans.toString()];
    }

    return WordEntry(
      headword: json['name']?.toString() ?? '',
      translations: normalizedTranslations,
      usPhonetic: json['usphone']?.toString(),
      ukPhonetic: json['ukphone']?.toString(),
      notation: json['notation']?.toString(),
    );
  }

  String get displayWord => headword.replaceAll(' ', '␣');

  String get translationText => translations.join('；');
}
