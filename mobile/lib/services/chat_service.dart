import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  final ApiClient _apiClient = ApiClient();

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

    final response = await _apiClient.dio.post(
      '/chat',
      data: body,
      options: Options(
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    final data = response.data;

    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] != null) {
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

  /// Restore a previous conversation by its ID
  void setConversationId(String id) {
    _conversationId = id;
  }

  /// Fetch the list of conversations for the current user (requires auth)
  Future<List<Map<String, dynamic>>> getConversations({int limit = 20}) async {
    final response = await _apiClient.dio.get(
      '/chat/conversations',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] != null) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    return [];
  }

  /// Fetch messages for a specific conversation
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final response = await _apiClient.dio.get(
      '/chat/conversations/$conversationId/messages',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] != null) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    return [];
  }
}
