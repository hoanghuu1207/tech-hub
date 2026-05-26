import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_model.dart';

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

class _ChatBottomSheetState extends State<ChatBottomSheet> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotController.dispose();
    super.dispose();
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
    return DraggableScrollableSheet(
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
                  // ── Messages ──
                  Expanded(child: _buildMessageList()),
                  // ── Input ──
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
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
                Text('TechBot', style: GoogleFonts.outfit(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _K.textPrimary,
                )),
                Text('AI Assistant', style: GoogleFonts.outfit(
                  fontSize: 12, color: _K.textSecondary,
                )),
              ],
            ),
          ),
          // Clear chat
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
  }

  Widget _buildMessageList() {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) => _scrollToBottom(),
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
                    _buildActionCard(msg.actionData!),
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
  Widget _buildActionCard(ChatActionData action) {
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
              onPressed: () => _openUrl(action.checkoutUrl),
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
          onTap: () {
            Navigator.pop(context);
            // Navigate to cart tab (index 2 in HomeScreen)
          },
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
          return Container(
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
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: _K.surface,
        border: Border(top: BorderSide(color: _K.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _K.bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _K.divider),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: GoogleFonts.outfit(fontSize: 14, color: _K.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Hỏi TechBot bất cứ điều gì...',
                  hintStyle: GoogleFonts.outfit(fontSize: 14, color: _K.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

  void _openUrl(String? url) {
    // TODO: Use url_launcher to open checkout URL
    if (url != null) {
      debugPrint('Opening URL: $url');
    }
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
