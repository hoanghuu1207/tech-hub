import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/index.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  WebSocketChannel? _wsChannel;
  ChatSession? _currentSession;

  ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  /// Initialize WebSocket connection
  Future<void> initWebSocket() async {
    try {
      final wsUrl = _apiService.wsUrl;
      final token = _authService.token;

      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/chat/ws?token=$token'),
      );

      // Listen to incoming messages
      _wsChannel?.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket closed');
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Send message to chat
  void sendMessage(String userMessage) {
    if (_wsChannel == null) {
      throw Exception('WebSocket not connected');
    }

    final message = {
      'type': 'message',
      'content': userMessage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _wsChannel?.sink.add(jsonEncode(message));
  }

  /// Send voice input
  void sendVoiceMessage(String audioPath) {
    if (_wsChannel == null) {
      throw Exception('WebSocket not connected');
    }

    final message = {
      'type': 'voice',
      'audio_path': audioPath,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _wsChannel?.sink.add(jsonEncode(message));
  }

  /// Get chat history
  Future<ChatSession> getChatHistory({int limit = 50}) async {
    try {
      final response = await _apiService.get(
        '/chat/history',
        queryParams: {'limit': limit},
        token: _authService.token,
      );

      final data = jsonDecode(response);
      _currentSession = ChatSession.fromJson(data['session']);

      return _currentSession!;
    } catch (e) {
      rethrow;
    }
  }

  /// Handle incoming WebSocket message
  void _handleIncomingMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'message') {
        // Handle text response from AI
        final chatMessage = ChatMessage(
          id: data['id'],
          role: ChatMessageRole.assistant,
          content: data['content'],
          timestamp: DateTime.parse(data['timestamp']),
          action: data['action'] != null
              ? ChatAction.fromJson(data['action'])
              : null,
        );

        _currentSession = _currentSession?.addMessage(chatMessage);
      } else if (type == 'action') {
        // Handle action from AI (search, add to cart, etc)
        _handleAIAction(data);
      } else if (type == 'error') {
        print('Chat error: ${data['message']}');
      }
    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }

  /// Handle AI triggered action
  void _handleAIAction(Map<String, dynamic> actionData) {
    final actionType = actionData['action_type'];
    final params = actionData['params'] as Map<String, dynamic>;

    // This will be handled by the app's navigation and state management
    // The UI layer will listen to these actions and respond accordingly
    print('AI Action: $actionType with params: $params');
  }

  /// Close WebSocket connection
  void closeConnection() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  // Getters
  ChatSession? get currentSession => _currentSession;
  bool get isConnected => _wsChannel != null;
}
