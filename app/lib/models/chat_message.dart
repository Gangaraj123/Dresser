class ChatOutfitSuggestion {
  final String name;
  final List<String> garmentIds;
  final int matchScore;
  final String reasoning;

  const ChatOutfitSuggestion({
    required this.name,
    required this.garmentIds,
    required this.matchScore,
    required this.reasoning,
  });

  factory ChatOutfitSuggestion.fromJson(Map<String, dynamic> json) {
    return ChatOutfitSuggestion(
      name: (json['name'] as String?) ?? 'Outfit',
      garmentIds: (json['garment_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
      reasoning: (json['reasoning'] as String?) ?? '',
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<ChatOutfitSuggestion> outfitSuggestions;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.outfitSuggestions = const [],
  });
}
