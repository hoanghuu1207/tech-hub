import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/index.dart';
import '../../models/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize chat connection
    context.read<ChatBloc>().add(const ChatInitializeRequested());
    context.read<ChatBloc>().add(const ChatLoadHistoryRequested());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: 'Trợ lý AI TechHub',
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is ChatMessageAdded || state is ChatConnected) {
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                List<ChatMessage> messages = [];

                if (state is ChatConnected) {
                  messages = state.messages;
                } else if (state is ChatMessageAdded) {
                  messages = state.messages;
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.smart_toy_outlined,
                          size: 64,
                          color: AppColors.gray300,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Hãy bắt đầu trò chuyện',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Text(
                            'Tôi là trợ lý AI của TechHub. Tôi có thể giúp bạn tìm kiếm, so sánh và mua sắm thiết bị công nghệ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isUser = message.role == ChatMessageRole.user;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isUser) ...[
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: const Icon(
                                Icons.smart_toy,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? AppColors.primary
                                    : AppColors.gray100,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color: isUser
                                          ? AppColors.white
                                          : AppColors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    AppFormatters.formatTimeAgo(
                                        message.timestamp),
                                    style: TextStyle(
                                      color: isUser
                                          ? AppColors.white.withOpacity(0.7)
                                          : AppColors.gray600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(
                  color: AppColors.gray200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.mic_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            // TODO: Start voice recording
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (_messageController.text.isNotEmpty) {
                          context.read<ChatBloc>().add(
                                ChatMessageSent(_messageController.text),
                              );
                          _messageController.clear();
                          _scrollToBottom();
                        }
                      },
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: const Icon(
                        Icons.send_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
