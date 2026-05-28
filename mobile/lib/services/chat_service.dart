import 'dart:convert';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  String? _conversationId;

  ChatService._internal();
  factory ChatService() => _instance;

  String? get conversationId => _conversationId;

  /// Send chat message via REST API
  Future<Map<String, dynamic>> sendMessage(String message) async {
    final body = <String, dynamic>{
      'message': message,
    };
    if (_conversationId != null) {
      body['conversation_id'] = _conversationId;
    }

    final response = await _apiService.post(
      '/chat',
      body: body,
      token: _authService.token,
    );

    final data = jsonDecode(response) as Map<String, dynamic>;

    if (data['success'] == true && data['data'] != null) {
      final chatData = data['data'] as Map<String, dynamic>;
      // Persist session_id for conversation continuity
      _conversationId = chatData['session_id'];
      return chatData;
    } else {
      throw Exception(data['error'] ?? 'Chat request failed');
    }
  }

  /// Start a new conversation
  void resetConversation() {
    _conversationId = null;
  }
}
