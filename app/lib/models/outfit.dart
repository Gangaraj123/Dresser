class Outfit {
  final String id;
  final String name;
  final String? occasion;
  final List<String> garmentIds;
  final bool aiGenerated;
  final String? aiReasoning;
  final int? matchScore;
  final int timesWorn;
  final String? lastWornDate;
  final bool isFavorite;
  final DateTime createdAt;

  const Outfit({
    required this.id,
    required this.name,
    this.occasion,
    required this.garmentIds,
    this.aiGenerated = false,
    this.aiReasoning,
    this.matchScore,
    this.timesWorn = 0,
    this.lastWornDate,
    this.isFavorite = false,
    required this.createdAt,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Outfit',
      occasion: json['occasion'] as String?,
      garmentIds: (json['garment_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      aiGenerated: (json['ai_generated'] as bool?) ?? false,
      aiReasoning: json['ai_reasoning'] as String?,
      matchScore: (json['match_score'] as num?)?.toInt(),
      timesWorn: (json['times_worn'] as num?)?.toInt() ?? 0,
      lastWornDate: json['last_worn_date'] as String?,
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
