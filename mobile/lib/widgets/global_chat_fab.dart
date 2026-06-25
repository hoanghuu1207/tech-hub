import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/cart_bloc.dart';
import 'chat_bottom_sheet.dart';

/// A global FAB that appears on every screen in the app.
/// Placed via MaterialApp.builder so it floats above all routes.
///
/// Hidden on auth screens (login, register, splash) and while
/// the chat bottom sheet is open.
class GlobalChatFAB extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const GlobalChatFAB({Key? key, required this.navigatorKey}) : super(key: key);

  /// Whether the current route allows the FAB (set by _FabRouteObserver).
  static bool _routeAllows = true;

  /// Whether the chat bottom sheet is currently open.
  static bool _sheetOpen = false;

  /// Combined visibility notifier.
  static final ValueNotifier<bool> visible = ValueNotifier(true);

  static void _update() {
    visible.value = _routeAllows && !_sheetOpen;
  }

  /// Called by _FabRouteObserver when navigating to a route that hides the FAB.
  static void hideForRoute() {
    _routeAllows = false;
    _update();
  }

  /// Called by _FabRouteObserver when navigating to a normal route.
  static void showForRoute() {
    _routeAllows = true;
    _update();
  }

  /// Called when the chat bottom sheet is opened.
  static void hideForSheet() {
    _sheetOpen = true;
    _update();
  }

  /// Called when the chat bottom sheet is dismissed.
  static void showForSheet() {
    _sheetOpen = false;
    _update();
  }

  @override
  State<GlobalChatFAB> createState() => _GlobalChatFABState();
}

class _GlobalChatFABState extends State<GlobalChatFAB> {
  static const _primaryColor = Color(0xFF6366F1);

  void _openChat(BuildContext context) {
    final navState = widget.navigatorKey.currentState;
    if (navState == null) return;

    // Pop any existing modal bottom sheet first to avoid stacking
    navState.popUntil((route) => route is! PopupRoute);

    final chatBloc = context.read<ChatBloc>();
    final cartBloc = context.read<CartBloc>();

    // Hide FAB while the bottom sheet is visible
    GlobalChatFAB.hideForSheet();

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
    ).whenComplete(() {
      // Re-show FAB when bottom sheet is dismissed
      GlobalChatFAB.showForSheet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GlobalChatFAB.visible,
      builder: (context, isVisible, child) {
        return AnimatedScale(
          scale: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !isVisible,
              child: child,
            ),
          ),
        );
      },
      child: Container(
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
      ),
    );
  }
}
