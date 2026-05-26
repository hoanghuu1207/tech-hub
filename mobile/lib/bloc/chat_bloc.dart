import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';

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

// ── States ──
class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isTyping;

  const ChatState({this.messages = const [], this.isTyping = false});

  ChatState copyWith({List<ChatMessage>? messages, bool? isTyping}) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  @override
  List<Object?> get props => [messages, isTyping];
}

// ── BLoC ──
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService _chatService = ChatService();

  ChatBloc() : super(const ChatState()) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatClearRequested>(_onClear);
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
    emit(state.copyWith(messages: updated, isTyping: true));

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

      emit(state.copyWith(messages: [...updated, botMsg], isTyping: false));
    } catch (e) {
      final errorMsg = ChatMessage(
        id: const Uuid().v4(),
        role: ChatMessageRole.assistant,
        content: 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại! 😊',
        timestamp: DateTime.now(),
      );
      emit(state.copyWith(messages: [...updated, errorMsg], isTyping: false));
    }
  }

  void _onClear(ChatClearRequested event, Emitter<ChatState> emit) {
    _chatService.resetConversation();
    emit(const ChatState());
  }
}
