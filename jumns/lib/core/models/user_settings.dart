class UserSettings {
  final String id;
  final String userId;
  final String agentName;
  final String agentBehavior;
  final bool onboardingCompleted;
  final String timezone;
  final String morningTime;
  final String eveningTime;
  final String model;
  final DateTime? createdAt;

  const UserSettings({
    required this.id,
    required this.userId,
    this.agentName = 'Jems',
    this.agentBehavior = 'friendly',
    this.onboardingCompleted = false,
    this.timezone = 'UTC',
    this.morningTime = '07:00',
    this.eveningTime = '21:00',
    this.model = 'gemini-2.5-flash',
    this.createdAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        agentName: json['agentName'] as String? ?? 'Jems',
        agentBehavior: json['agentBehavior'] as String? ?? 'friendly',
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
        timezone: json['timezone'] as String? ?? 'UTC',
        morningTime: json['morningTime'] as String? ?? '07:00',
        eveningTime: json['eveningTime'] as String? ?? '21:00',
        model: json['model'] as String? ?? 'gemini-2.5-flash',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  UserSettings copyWith({
    String? agentName,
    String? agentBehavior,
    bool? onboardingCompleted,
    String? timezone,
    String? morningTime,
    String? eveningTime,
    String? model,
  }) =>
      UserSettings(
        id: id,
        userId: userId,
        agentName: agentName ?? this.agentName,
        agentBehavior: agentBehavior ?? this.agentBehavior,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        timezone: timezone ?? this.timezone,
        morningTime: morningTime ?? this.morningTime,
        eveningTime: eveningTime ?? this.eveningTime,
        model: model ?? this.model,
        createdAt: createdAt,
      );

  /// Emoji for the current personality.
  String get personalityEmoji => switch (agentBehavior.toLowerCase()) {
        'coach' => '💪',
        'professional' => '📋',
        'zen' => '🧘',
        'creative' => '✨',
        _ => '😊',
      };

  /// Human-readable personality label.
  String get personalityLabel => switch (agentBehavior.toLowerCase()) {
        'coach' => 'Coach',
        'professional' => 'Professional',
        'zen' => 'Zen',
        'creative' => 'Creative',
        _ => 'Friendly',
      };

  /// Human-readable model label.
  String get modelLabel => switch (model) {
        'gemini-2.5-pro' => 'Gemini 2.5 Pro',
        'gemini-2.5-flash' => 'Gemini 2.5 Flash',
        'gemini-2.0-flash' => 'Gemini 2.0 Flash',
        _ => model,
      };
}

class SubscriptionStatus {
  final String plan;
  final bool isPro;
  final String? expiresAt;

  const SubscriptionStatus({
    this.plan = 'free',
    this.isPro = false,
    this.expiresAt,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        plan: json['plan'] as String? ?? 'free',
        isPro: json['isPro'] as bool? ?? json['entitled'] as bool? ?? false,
        expiresAt: json['expiresAt'] as String?,
      );
}
