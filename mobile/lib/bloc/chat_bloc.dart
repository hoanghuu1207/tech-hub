import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';

// ── Navigation Action ──
class ChatNavigationAction {
  final String action;
  final Map<String, dynamic> data;
  final DateTime timestamp; // Ensures BlocListener fires once per action

  ChatNavigationAction({
    required this.action,
    required this.data,
  }) : timestamp = DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatNavigationAction &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp;

  @override
  int get hashCode => timestamp.hashCode;
}

// ── Events ──
abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class ChatMessageSent extends ChatEvent {
  final String content;
  const ChatMessageSent(this.content);
  @override
  List<Object?> get props => [content];
}

class ChatClearRequested extends ChatEvent {
  const ChatClearRequested();
}

class ChatNavigationHandled extends ChatEvent {
  const ChatNavigationHandled();
}

/// Re-triggers a navigation action (e.g. when user taps an action card button)
class ChatNavigationRequested extends ChatEvent {
  final ChatNavigationAction navigation;
  const ChatNavigationRequested(this.navigation);
  @override
  List<Object?> get props => [navigation];
}

/// Load conversation list for the current user
class ChatLoadConversations extends ChatEvent {
  const ChatLoadConversations();
}

/// Load a specific conversation's messages and resume chatting
class ChatLoadConversation extends ChatEvent {
  final String conversationId;
  final String? title;
  const ChatLoadConversation(this.conversationId, {this.title});
  @override
  List<Object?> get props => [conversationId];
}

/// Go back to history list from a loaded conversation
class ChatBackToHistory extends ChatEvent {
  const ChatBackToHistory();
}

// ── States ──
class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isTyping;
  final ChatNavigationAction? pendingNavigation;

  /// Conversation history list
  final List<Map<String, dynamic>> conversations;
  final bool showHistory;
  final bool isLoadingHistory;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.pendingNavigation,
    this.conversations = const [],
    this.showHistory = false,
    this.isLoadingHistory = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    ChatNavigationAction? pendingNavigation,
    bool clearNavigation = false,
    List<Map<String, dynamic>>? conversations,
    bool? showHistory,
    bool? isLoadingHistory,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      pendingNavigation: clearNavigation ? null : (pendingNavigation ?? this.pendingNavigation),
      conversations: conversations ?? this.conversations,
      showHistory: showHistory ?? this.showHistory,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    );
  }

  @override
  List<Object?> get props => [messages, isTyping, pendingNavigation, conversations, showHistory, isLoadingHistory];
}

// ── BLoC ──
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService _chatService = ChatService();

  /// Actions that should trigger a screen navigation
  static const _screenActions = {
    'show_product_list',
    'navigate_product_detail',
    'show_cart',
    'cart_updated',
    'open_payment',
    'show_order_detail',
    'show_promotions',
    'require_login',
    'show_compare_table',
  };

  ChatBloc() : super(const ChatState()) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatClearRequested>(_onClear);
    on<ChatNavigationHandled>(_onNavigationHandled);
    on<ChatNavigationRequested>(_onNavigationRequested);
    on<ChatLoadConversations>(_onLoadConversations);
    on<ChatLoadConversation>(_onLoadConversation);
    on<ChatBackToHistory>(_onBackToHistory);
  }

  Future<void> _onMessageSent(ChatMessageSent event, Emitter<ChatState> emit) async {
    // 1. Add user message
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: ChatMessageRole.user,
      content: event.content,
      timestamp: DateTime.now(),
    );
    final updated = [...state.messages, userMsg];
    emit(state.copyWith(messages: updated, isTyping: true, clearNavigation: true));

    // 2. Call REST API
    try {
      final data = await _chatService.sendMessage(event.content);

      final botMsg = ChatMessage(
        id: const Uuid().v4(),
        role: ChatMessageRole.assistant,
        content: data['message'] ?? '',
        timestamp: DateTime.now(),
        intentType: data['intent_type'],
        actionData: data['action_data'] != null
            ? ChatActionData.fromJson(data['action_data'] as Map<String, dynamic>)
            : null,
        products: data['products'] as List<dynamic>?,
      );

      // 3. Build navigation action if applicable
      ChatNavigationAction? navAction;
      if (botMsg.actionData != null) {
        var action = botMsg.actionData!.action;
        final navData = Map<String, dynamic>.from(botMsg.actionData!.rawData);
        navData['intent_type'] = botMsg.intentType;

        if (_screenActions.contains(action)) {
          navAction = ChatNavigationAction(
            action: action,
            data: navData,
          );
        }
      }

      emit(ChatState(
        messages: [...updated, botMsg],
        isTyping: false,
        pendingNavigation: navAction,
        conversations: state.conversations,
        showHistory: false,
        isLoadingHistory: false,
      ));
    } catch (e) {
      print('❌ ChatBloc error: $e');
      final errorMsg = ChatMessage(
        id: const Uuid().v4(),
        role: ChatMessageRole.assistant,
        content: 'Xin lỗi, có lỗi xảy ra: $e',
        timestamp: DateTime.now(),
      );
      emit(state.copyWith(messages: [...updated, errorMsg], isTyping: false, clearNavigation: true));
    }
  }

  void _onClear(ChatClearRequested event, Emitter<ChatState> emit) {
    _chatService.resetConversation();
    emit(const ChatState());
  }

  void _onNavigationHandled(ChatNavigationHandled event, Emitter<ChatState> emit) {
    emit(state.copyWith(clearNavigation: true));
  }

  void _onNavigationRequested(ChatNavigationRequested event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      pendingNavigation: ChatNavigationAction(
        action: event.navigation.action,
        data: event.navigation.data,
      ),
    ));
  }

  // ── History ──

  Future<void> _onLoadConversations(ChatLoadConversations event, Emitter<ChatState> emit) async {
    emit(state.copyWith(showHistory: true, isLoadingHistory: true));
    try {
      final conversations = await _chatService.getConversations();
      emit(state.copyWith(conversations: conversations, isLoadingHistory: false));
    } catch (e) {
      print('❌ ChatBloc loadConversations error: $e');
      emit(state.copyWith(conversations: [], isLoadingHistory: false));
    }
  }

  Future<void> _onLoadConversation(ChatLoadConversation event, Emitter<ChatState> emit) async {
    // Show loading state while fetching messages
    emit(state.copyWith(showHistory: false, isTyping: true, messages: []));

    try {
      // Set the conversation ID so future messages continue this conversation
      _chatService.setConversationId(event.conversationId);

      final rawMessages = await _chatService.getMessages(event.conversationId);

      final messages = rawMessages.map((m) {
        final role = m['role'] == 'user' ? ChatMessageRole.user : ChatMessageRole.assistant;
        // Parse products_data if it exists and is a list of product maps
        List<dynamic>? products;
        if (m['products_data'] != null && m['products_data'] is List) {
          final rawProducts = m['products_data'] as List;
          // Filter out tool summary entries
          final realProducts = rawProducts.where((p) =>
              p is Map<String, dynamic> && !p.containsKey('_tool_summary')).toList();
          if (realProducts.isNotEmpty) {
            products = realProducts;
          }
        }
        return ChatMessage(
          id: m['id'] ?? const Uuid().v4(),
          role: role,
          content: m['content'] ?? '',
          timestamp: m['created_at'] != null
              ? DateTime.tryParse(m['created_at']) ?? DateTime.now()
              : DateTime.now(),
          intentType: m['intent_type'],
          products: products,
        );
      }).toList();

      emit(state.copyWith(messages: messages, isTyping: false, showHistory: false));
    } catch (e) {
      print('❌ ChatBloc loadConversation error: $e');
      emit(state.copyWith(isTyping: false, showHistory: false));
    }
  }

  void _onBackToHistory(ChatBackToHistory event, Emitter<ChatState> emit) {
    emit(state.copyWith(showHistory: false));
  }
}
