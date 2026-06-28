import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/cart_bloc.dart';
import '../models/chat_model.dart';
import '../screens/payment_webview_screen.dart';
import '../screens/chat_product_list_screen.dart';
import '../screens/compare_product_screen.dart';
import '../services/auth_service.dart';

// ── Colors ──
class _K {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFFBBF24);
  static const rose = Color(0xFFF43F5E);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
}

class ChatBottomSheet extends StatefulWidget {
  const ChatBottomSheet({Key? key}) : super(key: key);

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // When keyboard appears/disappears, scroll chat to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    // Fallback: delayed jump for when the list hasn't fully laid out yet
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(text));
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.0,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: const [0.0, 0.55, 0.92],
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: _K.bg.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: _K.primary.withOpacity(0.3), width: 1.5)),
                ),
                child: Column(
                  children: [
                    // ── Drag Handle ──
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: _K.textMuted.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── Header ──
                    _buildHeader(),
                    Divider(height: 1, color: _K.divider.withOpacity(0.5)),
                    // ── Messages or History ──
                    Expanded(
                      child: BlocBuilder<ChatBloc, ChatState>(
                        buildWhen: (prev, curr) => prev.showHistory != curr.showHistory,
                        builder: (context, state) {
                          if (state.showHistory) {
                            return _buildHistoryList();
                          }
                          return _buildMessageList();
                        },
                      ),
                    ),
                    // ── Input (hidden when showing history) ──
                    BlocBuilder<ChatBloc, ChatState>(
                      buildWhen: (prev, curr) => prev.showHistory != curr.showHistory,
                      builder: (context, state) {
                        if (state.showHistory) return const SizedBox.shrink();
                        return _buildInputBar();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) => prev.showHistory != curr.showHistory,
      builder: (context, state) {
        final isHistory = state.showHistory;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Pulsing green dot
              _PulsingDot(controller: _dotController),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHistory ? 'Lịch sử chat' : 'TechBot',
                      style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700, color: _K.textPrimary,
                      ),
                    ),
                    Text(
                      isHistory ? 'Chọn cuộc trò chuyện' : 'AI Assistant',
                      style: GoogleFonts.outfit(
                        fontSize: 12, color: _K.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // History / Back to chat toggle
              if (AuthService().isTokenValid)
                IconButton(
                  onPressed: () {
                    if (isHistory) {
                      // Go back to current chat (just hide history)
                      context.read<ChatBloc>().add(const ChatBackToHistory());
                    } else {
                      context.read<ChatBloc>().add(const ChatLoadConversations());
                    }
                  },
                  icon: Icon(
                    isHistory ? Icons.arrow_back_rounded : Icons.history_rounded,
                    color: _K.textMuted, size: 20,
                  ),
                  tooltip: isHistory ? 'Quay lại' : 'Lịch sử chat',
                ),
              // New conversation
              IconButton(
                onPressed: () => context.read<ChatBloc>().add(const ChatClearRequested()),
                icon: const Icon(Icons.refresh_rounded, color: _K.textMuted, size: 20),
                tooltip: 'Cuộc trò chuyện mới',
              ),
              // Close
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _K.textMuted, size: 22),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        _scrollToBottom();
        if (state.messages.isNotEmpty) {
          final lastMsg = state.messages.last;
          if (lastMsg.role == ChatMessageRole.assistant && lastMsg.actionData != null) {
            final action = lastMsg.actionData!.action;
            if (action == 'cart_updated' || action == 'show_cart') {
              context.read<CartBloc>().add(const CartFetch());
            }
          }
        }
      },
      builder: (context, state) {
        if (state.messages.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: state.messages.length + (state.isTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.messages.length && state.isTyping) {
              return _buildTypingIndicator();
            }
            return _buildMessageBubble(state.messages[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _K.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: _K.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Xin chào! 👋', style: GoogleFonts.outfit(
              fontSize: 20, fontWeight: FontWeight.w700, color: _K.textPrimary,
            )),
            const SizedBox(height: 8),
            Text('Tôi là TechBot, trợ lý AI mua sắm.\nHỏi tôi về sản phẩm, đặt hàng, hay bất cứ điều gì!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: _K.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Tìm laptop dưới 20 triệu'),
                _buildSuggestionChip('iPhone mới nhất giá bao nhiêu?'),
                _buildSuggestionChip('Xem giỏ hàng'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _K.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _K.divider),
        ),
        child: Text(text, style: GoogleFonts.outfit(fontSize: 12, color: _K.textSecondary)),
      ),
    );
  }

  // ── HISTORY LIST ──
  Widget _buildHistoryList() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) =>
          prev.conversations != curr.conversations ||
          prev.isLoadingHistory != curr.isLoadingHistory,
      builder: (context, state) {
        if (state.isLoadingHistory) {
          return const Center(
            child: CircularProgressIndicator(color: _K.primary, strokeWidth: 2.5),
          );
        }

        if (state.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _K.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.forum_outlined, color: _K.primary, size: 28),
                ),
                const SizedBox(height: 14),
                Text('Chưa có cuộc trò chuyện nào',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: _K.textPrimary)),
                const SizedBox(height: 6),
                Text('Bắt đầu trò chuyện với TechBot!',
                  style: GoogleFonts.outfit(fontSize: 13, color: _K.textMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: state.conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final conv = state.conversations[index];
            final title = conv['title'] ?? 'Cuộc trò chuyện mới';
            final updatedAt = conv['updated_at'] != null
                ? DateTime.tryParse(conv['updated_at'])
                : null;
            final convId = conv['id'] as String;

            return GestureDetector(
              onTap: () {
                context.read<ChatBloc>().add(ChatLoadConversation(convId, title: title));
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _K.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _K.divider.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: _K.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded, color: _K.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _K.textPrimary, height: 1.3,
                            ),
                          ),
                          if (updatedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _formatConversationTime(updatedAt),
                                style: GoogleFonts.outfit(fontSize: 11, color: _K.textMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: _K.textMuted, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatConversationTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  // ── MESSAGE BUBBLE ──
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == ChatMessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _K.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: _K.primary, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _K.primary : _K.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: _K.divider.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.content, style: GoogleFonts.outfit(
                    fontSize: 14, color: _K.textPrimary, height: 1.4,
                  )),
                  // ── Action Cards ──
                  if (msg.actionData != null) ...[
                    const SizedBox(height: 10),
                    _buildActionCard(msg.actionData!, products: msg.products),
                  ],
                  // ── Products ──
                  if (msg.products != null && msg.products!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildProductList(msg.products!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTION CARDS ──
  Widget _buildActionCard(ChatActionData action, {List<dynamic>? products}) {
    switch (action.action) {
      case 'select_variant':
        return _buildVariantSelector(action);
      case 'open_payment':
        return _buildPaymentCard(action);
      case 'cart_updated':
        return _buildCartUpdatedCard(action);
      case 'require_login':
        return _buildLoginCard();
      case 'show_cart':
        return _buildShowCartCard(action);
      case 'show_product_list':
      case 'show_promotions':
        return _buildViewListCard(action, products: products);
      case 'navigate_product_detail':
        return _buildViewDetailCard(action);
      case 'show_order_detail':
        return _buildViewOrderCard(action);
      case 'show_compare_table':
        return _buildCompareCard(action);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── VARIANT SELECTOR ──
  Widget _buildVariantSelector(ChatActionData action) {
    final variants = action.variants;
    if (variants == null || variants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn màu:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _K.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: variants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final v = variants[index];
              final inStock = v.stockQuantity > 0;
              return GestureDetector(
                onTap: inStock ? () {
                  context.read<ChatBloc>().add(ChatMessageSent('Tôi chọn màu ${v.colorName}'));
                } : null,
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _K.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: inStock ? _K.divider : _K.rose.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: _parseHex(v.colorHex),
                          shape: BoxShape.circle,
                          border: Border.all(color: _K.textMuted, width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(v.colorName, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: _K.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_formatPrice(v.price), style: GoogleFonts.outfit(fontSize: 10, color: _K.emerald)),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: inStock ? _K.emerald.withOpacity(0.15) : _K.rose.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          inStock ? 'Còn ${v.stockQuantity}' : 'Hết hàng',
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: inStock ? _K.emerald : _K.rose),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── PAYMENT CARD ──
  Widget _buildPaymentCard(ChatActionData action) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_K.primary.withOpacity(0.2), _K.emerald.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _K.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_rounded, color: _K.primary, size: 18),
            const SizedBox(width: 8),
            Text('Đơn hàng #${action.orderCode}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: _K.textPrimary)),
          ]),
          const SizedBox(height: 8),
          Text('Tổng: ${_formatPrice(action.totalAmount ?? 0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _K.emerald)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final url = action.checkoutUrl;
                final orderId = action.orderId;
                if (url != null && url.isNotEmpty) {
                  final nav = Navigator.of(context);
                  nav.pop(); // close bottom sheet
                  nav.push(MaterialPageRoute(
                    builder: (_) => PaymentWebViewScreen(
                      checkoutUrl: url,
                      orderId: orderId ?? '',
                    ),
                  ));
                }
              },
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: Text('Thanh toán PayOS', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CART UPDATED CARD ──
  Widget _buildCartUpdatedCard(ChatActionData action) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _K.emerald.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _K.emerald.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _K.emerald.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: _K.emerald, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đã thêm vào giỏ hàng!', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _K.emerald)),
              if (action.productName != null)
                Text('${action.productName} - ${action.colorName ?? ''}', style: GoogleFonts.outfit(fontSize: 11, color: _K.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  // ── LOGIN REQUIRED CARD ──
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _K.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _K.amber.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: _K.amber, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('Bạn cần đăng nhập để thực hiện.', style: GoogleFonts.outfit(fontSize: 13, color: _K.textPrimary))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed('/login');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _K.amber, borderRadius: BorderRadius.circular(8)),
            child: Text('Đăng nhập', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: _K.bg)),
          ),
        ),
      ]),
    );
  }

  // ── SHOW CART CARD ──
  Widget _buildShowCartCard(ChatActionData action) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _K.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _K.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.shopping_bag_rounded, color: _K.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('Giỏ hàng: ${action.totalItems ?? 0} sản phẩm', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _K.textPrimary))),
        GestureDetector(
          onTap: () => _requestNavAndClose('show_cart', action.rawData),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _K.primary, borderRadius: BorderRadius.circular(8)),
            child: Text('Xem', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ── PRODUCT LIST (from search results) ──
  Widget _buildProductList(List<dynamic> products) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length > 5 ? 5 : products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = products[index] as Map<String, dynamic>;
          return GestureDetector(
            onTap: () {
              final id = (p['id'] ?? p['product_id'] ?? '').toString();
              if (id.isEmpty) return;
              final nav = Navigator.of(context);
              nav.pop(); // close bottom sheet
              nav.popUntil((route) => route.isFirst);
              nav.pushNamed('/product-detail', arguments: id);
            },
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _K.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _K.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p['primary_image'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(p['primary_image'], height: 56, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 56, color: _K.surface, child: const Icon(Icons.image, color: _K.textMuted, size: 24))),
                    )
                  else
                    Container(height: 56, decoration: BoxDecoration(color: _K.surface, borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Icon(Icons.devices, color: _K.textMuted, size: 24))),
                  const SizedBox(height: 6),
                  Text(p['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: _K.textPrimary, height: 1.2)),
                  const Spacer(),
                  Text(_formatPrice((p['sale_price'] ?? p['base_price'] ?? 0).toDouble()),
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: _K.emerald)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TYPING INDICATOR ──
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: _K.primary.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded, color: _K.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _K.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: _K.divider.withOpacity(0.5)),
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.33;
                    final t = ((_dotController.value - delay) % 1.0).clamp(0.0, 1.0);
                    final y = -4.0 * (t < 0.5 ? t * 2 : 2 - t * 2);
                    return Transform.translate(
                      offset: Offset(0, y),
                      child: Container(
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: _K.primary.withOpacity(0.6 + 0.4 * (1 - t)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── INPUT BAR ──
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12, 10, 12,
        MediaQuery.of(context).viewInsets.bottom > 0
          ? 10
          : MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: _K.surface,
        border: Border(top: BorderSide(color: _K.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white), // black
                decoration: InputDecoration(
                  hintText: 'Hỏi TechBot bất cứ điều gì...',
                  hintStyle: GoogleFonts.outfit(fontSize: 14, color: _K.textMuted),
                  filled: true,
                  fillColor: _K.bg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _K.divider,
                    ),
                  ),
                   enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _K.divider,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _K.divider,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _K.primary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _K.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ──
  Color _parseHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _formatPrice(double price) {
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(price)}đ';
  }
  /// Pops back to HomeScreen first, then dispatches navigation event on next frame.
  /// This ensures HomeScreen is fully visible before BlocListener switches tabs.
  void _requestNavAndClose(String action, Map<String, dynamic> data) {
    final chatBloc = context.read<ChatBloc>();
    final nav = Navigator.of(context);
    nav.pop(); // close bottom sheet
    nav.popUntil((route) => route.isFirst); // pop back to HomeScreen

    // Dispatch navigation AFTER pops complete so HomeScreen rebuilds fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatBloc.add(ChatNavigationRequested(
        ChatNavigationAction(action: action, data: data),
      ));
    });
  }

  // ── VIEW LIST CARD (search results / promotions) ──
  Widget _buildViewListCard(ChatActionData action, {List<dynamic>? products}) {
    final isPromo = action.action == 'show_promotions';
    return _buildSimpleActionCard(
      icon: isPromo ? Icons.local_offer_rounded : Icons.grid_view_rounded,
      color: isPromo ? _K.amber : _K.primary,
      label: isPromo ? 'Xem sản phẩm khuyến mãi' : 'Xem danh sách sản phẩm',
      onTap: () {
        if (products != null && products.isNotEmpty) {
          final productMaps = products
              .whereType<Map<String, dynamic>>()
              .toList();
          final nav = Navigator.of(context);
          nav.pop(); // close bottom sheet
          nav.push(MaterialPageRoute(
            builder: (_) => ChatProductListScreen(
              products: productMaps,
              title: isPromo ? 'Sản phẩm khuyến mãi' : 'Kết quả tìm kiếm',
            ),
          ));
        } else {
          _requestNavAndClose(action.action, action.rawData);
        }
      },
    );
  }

  // ── VIEW DETAIL CARD ──
  Widget _buildViewDetailCard(ChatActionData action) {
    return _buildSimpleActionCard(
      icon: Icons.open_in_new_rounded,
      color: _K.emerald,
      label: 'Xem chi tiết ${action.productName ?? "sản phẩm"}',
      onTap: () {
        final id = action.productId;
        if (id == null) return;
        final nav = Navigator.of(context);
        nav.pop(); // close bottom sheet
        // Pop any stacked screens back to root, then push detail
        nav.popUntil((route) => route.isFirst);
        nav.pushNamed('/product-detail', arguments: id);
      },
    );
  }

  // ── VIEW ORDER CARD ──
  Widget _buildViewOrderCard(ChatActionData action) {
    return _buildSimpleActionCard(
      icon: Icons.receipt_long_rounded,
      color: _K.amber,
      label: 'Xem đơn hàng',
      onTap: () => _requestNavAndClose('show_order_detail', action.rawData),
    );
  }

  // ── COMPARE CARD ──
  Widget _buildCompareCard(ChatActionData action) {
    return _buildSimpleActionCard(
      icon: Icons.compare_arrows_rounded,
      color: _K.primary,
      label: 'Xem bảng so sánh',
      onTap: () {
        final ids = action.productIds;
        if (ids != null && ids.length >= 2) {
          final nav = Navigator.of(context);
          nav.pop(); // close bottom sheet
          nav.push(MaterialPageRoute(
            builder: (_) => CompareProductScreen(productIds: ids),
          ));
        }
      },
    );
  }

  // ── REUSABLE SIMPLE ACTION CARD ──
  Widget _buildSimpleActionCard({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: GoogleFonts.outfit(
                fontSize: 13, fontWeight: FontWeight.w600, color: _K.textPrimary,
              )),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── PULSING GREEN DOT ──
class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  const _PulsingDot({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scale = 1.0 + 0.3 * ((controller.value * 2 * 3.14159).clamp(0, 6.28) < 3.14 ? controller.value : 1 - controller.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: _K.emerald,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _K.emerald.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
        );
      },
    );
  }
}
