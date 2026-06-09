import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/cart_bloc.dart';
import 'chat_bottom_sheet.dart';

/// A global FAB that appears on every screen in the app.
/// Placed via MaterialApp.builder so it floats above all routes.
class GlobalChatFAB extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const GlobalChatFAB({Key? key, required this.navigatorKey}) : super(key: key);

  static const _primaryColor = Color(0xFF6366F1);

  void _openChat(BuildContext context) {
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    // Pop any existing modal bottom sheet first to avoid stacking
    // (safe to call even if no modal is showing — popUntil stops at first match)
    navState.popUntil((route) => route is! PopupRoute);

    final chatBloc = context.read<ChatBloc>();
    final cartBloc = context.read<CartBloc>();

    showModalBottomSheet(
      context: navState.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: chatBloc),
          BlocProvider.value(value: cartBloc),
        ],
        child: const ChatBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'global_chat_fab',
        onPressed: () => _openChat(context),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.psychology, size: 28),
      ),
    );
  }
}
