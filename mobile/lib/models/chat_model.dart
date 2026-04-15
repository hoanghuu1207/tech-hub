enum ChatMessageRole { user, assistant }
enum ChatActionType { search, compare, addToCart, checkout }

class ChatMessage {
  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading;
  final ChatAction? action;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
    this.action,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: ChatMessageRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLoading: json['is_loading'] as bool? ?? false,
      action: json['action'] != null 
          ? ChatAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_loading': isLoading,
      'action': action?.toJson(),
    };
  }

  ChatMessage copyWith({
    String? id,
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isLoading,
    ChatAction? action,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      action: action ?? this.action,
    );
  }
}

class ChatAction {
  final ChatActionType type;
  final Map<String, dynamic> params;

  ChatAction({
    required this.type,
    required this.params,
  });

  factory ChatAction.fromJson(Map<String, dynamic> json) {
    return ChatAction(
      type: ChatActionType.values.byName(json['type'] as String),
      params: json['params'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'params': params,
    };
  }
}

class ChatSession {
  final String id;
  final String userId;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.userId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatSession addMessage(ChatMessage message) {
    return ChatSession(
      id: id,
      userId: userId,
      messages: [...messages, message],
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      messages: List<ChatMessage>.from(
        (json['messages'] as List).map((msg) => ChatMessage.fromJson(msg as Map<String, dynamic>)),
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
