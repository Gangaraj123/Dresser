class Garment {
  final String id;
  final String category; // topwear | bottomwear | footwear | outerwear | accessory
  final String? subCategory;
  final String? displayImageUrl;
  final String? thumbnailUrl;
  final String? dominantColorHex;
  final String? dominantColorName;
  final String? pattern;
  final String? fabric;
  final int? formalityScore;
  final List<String> seasonSuitability;
  final String? brand;
  final int timesWorn;
  final String? lastWornDate;
  final int? skinCompatibilityScore;
  final double? aiConfidence;
  final DateTime createdAt;

  const Garment({
    required this.id,
    required this.category,
    this.subCategory,
    this.displayImageUrl,
    this.thumbnailUrl,
    this.dominantColorHex,
    this.dominantColorName,
    this.pattern,
    this.fabric,
    this.formalityScore,
    this.seasonSuitability = const [],
    this.brand,
    this.timesWorn = 0,
    this.lastWornDate,
    this.skinCompatibilityScore,
    this.aiConfidence,
    required this.createdAt,
  });

  /// True while the background product-photo job is still running.
  /// Signalled by thumbnail_url being null on the server.
  bool get isProcessing => thumbnailUrl == null;

  /// Human-readable display name: sub_category if available, else capitalised category.
  String get displayName {
    if (subCategory != null && subCategory!.isNotEmpty) return subCategory!;
    return _capitalise(category);
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'sub_category': subCategory,
        'display_image_url': displayImageUrl,
        'thumbnail_url': thumbnailUrl,
        'dominant_color_hex': dominantColorHex,
        'dominant_color_name': dominantColorName,
        'pattern': pattern,
        'fabric': fabric,
        'formality_score': formalityScore,
        'season_suitability': seasonSuitability,
        'brand': brand,
        'times_worn': timesWorn,
        'last_worn_date': lastWornDate,
        'skin_compatibility_score': skinCompatibilityScore,
        'ai_confidence': aiConfidence,
        'created_at': createdAt.toIso8601String(),
      };

  factory Garment.fromJson(Map<String, dynamic> json) {
    return Garment(
      id: json['id'] as String,
      category: (json['category'] as String?) ?? 'topwear',
      subCategory: json['sub_category'] as String?,
      displayImageUrl: json['display_image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      dominantColorHex: json['dominant_color_hex'] as String?,
      dominantColorName: json['dominant_color_name'] as String?,
      pattern: json['pattern'] as String?,
      fabric: json['fabric'] as String?,
      formalityScore: (json['formality_score'] as num?)?.toInt(),
      seasonSuitability: (json['season_suitability'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      brand: json['brand'] as String?,
      timesWorn: (json['times_worn'] as num?)?.toInt() ?? 0,
      lastWornDate: json['last_worn_date'] as String?,
      skinCompatibilityScore:
          (json['skin_compatibility_score'] as num?)?.toInt(),
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class WardrobeStats {
  final int total;
  final int topwear;
  final int bottomwear;
  final int footwear;
  final int outerwear;
  final int accessory;

  const WardrobeStats({
    required this.total,
    required this.topwear,
    required this.bottomwear,
    required this.footwear,
    required this.outerwear,
    required this.accessory,
  });

  factory WardrobeStats.fromJson(Map<String, dynamic> json) {
    return WardrobeStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      topwear: (json['topwear'] as num?)?.toInt() ?? 0,
      bottomwear: (json['bottomwear'] as num?)?.toInt() ?? 0,
      footwear: (json['footwear'] as num?)?.toInt() ?? 0,
      outerwear: (json['outerwear'] as num?)?.toInt() ?? 0,
      accessory: (json['accessory'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = WardrobeStats(
    total: 0,
    topwear: 0,
    bottomwear: 0,
    footwear: 0,
    outerwear: 0,
    accessory: 0,
  );
}
