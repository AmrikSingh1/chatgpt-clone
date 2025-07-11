class AIModel {
  final String id;
  final String name;
  final String description;
  final int maxTokens;
  final double costPer1kTokens;
  final bool isDefault;

  AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.maxTokens,
    required this.costPer1kTokens,
    this.isDefault = false,
  });

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      maxTokens: json['maxTokens'],
      costPer1kTokens: json['costPer1kTokens'].toDouble(),
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'maxTokens': maxTokens,
      'costPer1kTokens': costPer1kTokens,
      'isDefault': isDefault,
    };
  }

  static List<AIModel> defaultModels() {
    return [
      AIModel(
        id: 'gpt-3.5-turbo',
        name: 'GPT-3.5 Turbo',
        description: 'Fast and efficient for most conversations',
        maxTokens: 4096,
        costPer1kTokens: 0.002,
        isDefault: true,
      ),
      AIModel(
        id: 'gpt-4',
        name: 'GPT-4',
        description: 'More capable but slower, best for complex tasks',
        maxTokens: 8192,
        costPer1kTokens: 0.03,
      ),
      AIModel(
        id: 'gpt-4-turbo-preview',
        name: 'GPT-4 Turbo',
        description: 'Latest GPT-4 model with improved performance',
        maxTokens: 128000,
        costPer1kTokens: 0.01,
      ),
    ];
  }
} 