class TranslationItem {
  final String id;
  final String sourceText;
  final String translatedText;
  final DateTime timestamp;
  final bool isFavorite;

  TranslationItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.timestamp,
    required this.isFavorite,
  });

  factory TranslationItem.fromJson(Map<String, dynamic> json) {
    return TranslationItem(
      id: json['_id'] ?? '',
      sourceText: json['original_text'] ?? '',
      translatedText: json['translated_text'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isFavorite: json['is_favorite'] ?? false,
    );
  }
}
