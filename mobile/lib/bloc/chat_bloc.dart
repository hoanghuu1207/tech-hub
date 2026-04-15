import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/index.dart';
import '../../services/index.dart';
import 'package:uuid/uuid.dart';

// Events
abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class ChatInitializeRequested extends ChatEvent {
  const ChatInitializeRequested();
}

class ChatMessageSent extends ChatEvent {
  final String content;

  const ChatMessageSent(this.content);

  @override
  List<Object?> get props => [content];
}

class ChatVoiceMessageSent extends ChatEvent {
  final String audioPath;

  const ChatVoiceMessageSent(this.audioPath);

  @override
  List<Object?> get props => [audioPath];
}

class ChatMessageReceived extends ChatEvent {
  final ChatMessage message;

  const ChatMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class ChatLoadHistoryRequested extends ChatEvent {
  const ChatLoadHistoryRequested();
}

class ChatClearRequested extends ChatEvent {
  const ChatClearRequested();
}

// States
abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatConnected extends ChatState {
  final List<ChatMessage> messages;

  const ChatConnected(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatMessageAdded extends ChatState {
  final List<ChatMessage> messages;
  final ChatMessage newMessage;

  const ChatMessageAdded(this.messages, this.newMessage);

  @override
  List<Object?> get props => [messages, newMessage];
}

class ChatFailure extends ChatState {
  final String message;

  const ChatFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService _chatService = ChatService();
  List<ChatMessage> _messages = [];

  ChatBloc() : super(const ChatInitial()) {
    on<ChatInitializeRequested>(_onChatInitializeRequested);
    on<ChatMessageSent>(_onChatMessageSent);
    on<ChatVoiceMessageSent>(_onChatVoiceMessageSent);
    on<ChatMessageReceived>(_onChatMessageReceived);
    on<ChatLoadHistoryRequested>(_onChatLoadHistoryRequested);
    on<ChatClearRequested>(_onChatClearRequested);
  }

  Future<void> _onChatInitializeRequested(
    ChatInitializeRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    try {
      await _chatService.initWebSocket();
      emit(ChatConnected(_messages));
    } catch (e) {
      emit(ChatFailure(e.toString()));
    }
  }

  Future<void> _onChatMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Add user message locally
      final userMessage = ChatMessage(
        id: const Uuid().v4(),
        role: ChatMessageRole.user,
        content: event.content,
        timestamp: DateTime.now(),
      );

      _messages.add(userMessage);
      emit(ChatMessageAdded(_messages, userMessage));

      // Send through WebSocket (AI will respond)
      _chatService.sendMessage(event.content);
    } catch (e) {
      emit(ChatFailure(e.toString()));
    }
  }

  Future<void> _onChatVoiceMessageSent(
    ChatVoiceMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      _chatService.sendVoiceMessage(event.audioPath);
    } catch (e) {
      emit(ChatFailure(e.toString()));
    }
  }

  Future<void> _onChatMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) async {
    _messages.add(event.message);
    emit(ChatMessageAdded(_messages, event.message));
  }

  Future<void> _onChatLoadHistoryRequested(
    ChatLoadHistoryRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    try {
      final session = await _chatService.getChatHistory();
      _messages = session.messages;
      emit(ChatConnected(_messages));
    } catch (e) {
      emit(ChatFailure(e.toString()));
    }
  }

  Future<void> _onChatClearRequested(
    ChatClearRequested event,
    Emitter<ChatState> emit,
  ) async {
    _messages = [];
    emit(ChatConnected(_messages));
  }

  @override
  Future<void> close() {
    _chatService.closeConnection();
    return super.close();
  }
}
