class MarketplaceAgent {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final String accent;
  final String icon;
  final List<String> tools;
  final String publisher;
  final String version;
  final String? a2aEndpoint;
  final String category;
  final bool isInstalled;
  final bool isMarketplace;
  final String? installedAt;

  const MarketplaceAgent({
    required this.id,
    required this.name,
    required this.displayName,
    this.description = '',
    this.accent = '#94A3B8',
    this.icon = 'extension',
    this.tools = const [],
    this.publisher = '',
    this.version = '1.0.0',
    this.a2aEndpoint,
    this.category = 'general',
    this.isInstalled = false,
    this.isMarketplace = false,
    this.installedAt,
  });

  factory MarketplaceAgent.fromJson(Map<String, dynamic> json) => MarketplaceAgent(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        displayName: json['displayName'] as String? ?? json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        accent: json['accent'] as String? ?? '#94A3B8',
        icon: json['icon'] as String? ?? 'extension',
        tools: (json['tools'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        publisher: json['publisher'] as String? ?? '',
        version: json['version'] as String? ?? '1.0.0',
        a2aEndpoint: json['a2a_endpoint'] as String?,
        category: json['category'] as String? ?? 'general',
        isInstalled: json['isInstalled'] as bool? ?? false,
        isMarketplace: json['isMarketplace'] as bool? ?? false,
        installedAt: json['installedAt'] as String?,
      );
}
