import 'message.dart';

class Chat {
  final String id;
  final String title;
  final String model;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Chat({
    required this.id,
    required this.title,
    required this.model,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      title: json['title'],
      model: json['model'],
      messages: (json['messages'] as List<dynamic>?)
          ?.map((message) => Message.fromJson(message))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'model': model,
      'messages': messages.map((message) => message.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  Chat copyWith({
    String? id,
    String? title,
    String? model,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      model: model ?? this.model,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  String get lastMessagePreview {
    if (messages.isEmpty) return '';
    final lastMessage = messages.last;
    return lastMessage.content.length > 100 
        ? '${lastMessage.content.substring(0, 100)}...'
        : lastMessage.content;
  }

  bool get hasMessages => messages.isNotEmpty;
}

class ChatPreview {
  final String id;
  final String title;
  final String model;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatPreview({
    required this.id,
    required this.title,
    required this.model,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    return ChatPreview(
      id: json['id'],
      title: json['title'],
      model: json['model'],
      lastMessage: json['lastMessage'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
} 