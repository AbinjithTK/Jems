/// Journal entry model — matches backend JournalEntryResponse (camelCase).
class JournalEntry {
  final String id;
  final String userId;
  final String type; // thought, reflection, polaroid, audio, sticky
  final String title;
  final String content;
  final String? mood;
  final List<String> tags;
  final bool shareable;
  final bool draft;
  final bool agentPrompted;
  final String? linkedGoalId;
  final String? mediaUrl;
  final DateTime? createdAt;

  const JournalEntry({
    required this.id,
    required this.userId,
    this.type = 'thought',
    this.title = '',
    this.content = '',
    this.mood,
    this.tags = const [],
    this.shareable = false,
    this.draft = true,
    this.agentPrompted = false,
    this.linkedGoalId,
    this.mediaUrl,
    this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        type: json['type'] as String? ?? 'thought',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        mood: json['mood'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        shareable: json['shareable'] as bool? ?? false,
        draft: json['draft'] as bool? ?? true,
        agentPrompted: json['agentPrompted'] as bool? ?? false,
        linkedGoalId: json['linkedGoalId'] as String?,
        mediaUrl: json['mediaUrl'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  bool get hasImage => mediaUrl != null && mediaUrl!.isNotEmpty;
}
