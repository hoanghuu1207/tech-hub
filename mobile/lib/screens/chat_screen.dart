import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../widgets/chat_bottom_sheet.dart';

/// Legacy ChatScreen — now redirects to the ChatBottomSheet.
/// Kept for backward compatibility with existing routes.
class ChatScreen extends StatelessWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Immediately open the bottom sheet and pop this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<ChatBloc>(),
          child: const ChatBottomSheet(),
        ),
      );
    });

    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
    );
  }
}
