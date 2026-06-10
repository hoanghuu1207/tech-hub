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

// ── States ──
class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isTyping;
  final ChatNavigationAction? pendingNavigation;

  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.pendingNavigation,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    ChatNavigationAction? pendingNavigation,
    bool clearNavigation = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      pendingNavigation: clearNavigation ? null : (pendingNavigation ?? this.pendingNavigation),
    );
  }

  @override
  List<Object?> get props => [messages, isTyping, pendingNavigation];
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
}
