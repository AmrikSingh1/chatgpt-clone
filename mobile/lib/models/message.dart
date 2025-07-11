import 'package:uuid/uuid.dart';

class Message {
  final String id;
  final String role;
  final String content;
  final List<MessageImage> images;
  final DateTime timestamp;
  final bool hasAnimated; // Track if typewriter animation has completed

  Message({
    String? id,
    required this.role,
    required this.content,
    List<MessageImage>? images,
    DateTime? timestamp,
    this.hasAnimated = false, // Default to false for new messages
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        images = images ?? [];

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      images: (json['images'] as List<dynamic>?)
          ?.map((image) => MessageImage.fromJson(image))
          .toList() ?? [],
      timestamp: DateTime.parse(json['timestamp']),
      hasAnimated: json['hasAnimated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'images': images.map((image) => image.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'hasAnimated': hasAnimated,
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasImages => images.isNotEmpty;

  Message copyWith({
    String? id,
    String? role,
    String? content,
    List<MessageImage>? images,
    DateTime? timestamp,
    bool? hasAnimated,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      images: images ?? this.images,
      timestamp: timestamp ?? this.timestamp,
      hasAnimated: hasAnimated ?? this.hasAnimated,
    );
  }
}

class MessageImage {
  final String id;
  final String url;
  final String? publicId;
  final String? filename;

  MessageImage({
    String? id,
    required this.url,
    this.publicId,
    this.filename,
  }) : id = id ?? const Uuid().v4();

  factory MessageImage.fromJson(Map<String, dynamic> json) {
    return MessageImage(
      id: json['id'],
      url: json['url'],
      publicId: json['publicId'],
      filename: json['filename'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'publicId': publicId,
      'filename': filename,
    };
  }
  
  // API-specific JSON without id field (backend doesn't expect id)
  Map<String, dynamic> toApiJson() {
    return {
      'url': url,
      if (publicId != null) 'publicId': publicId,
      if (filename != null) 'filename': filename,
    };
  }
} 