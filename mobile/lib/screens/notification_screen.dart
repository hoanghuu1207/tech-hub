import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';

// ── Theme ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const rose = Color(0xFFF43F5E);
  static const amber = Color(0xFFFBBF24);
  static const divider = Color(0xFF334155);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getNotifications();
      if (mounted) setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    _loadNotifications();
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'out_of_stock':
        return Icons.remove_shopping_cart_rounded;
      case 'order_status':
        return Icons.local_shipping_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'out_of_stock':
        return _C.rose;
      case 'order_status':
        return _C.primary;
      case 'promo':
        return _C.amber;
      default:
        return _C.textMuted;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return AppFormatters.formatDate(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Thông báo',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: Text('Đọc tất cả',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primary)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: _C.primary,
                  backgroundColor: _C.surface,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _C.divider.withOpacity(0.3), indent: 72),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return _buildNotificationTile(notif);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationTile(AppNotification notif) {
    final color = _colorForType(notif.type);
    return InkWell(
      onTap: () async {
        if (!notif.isRead) {
          await _service.markAsRead(notif.id);
          _loadNotifications();
        }
      },
      child: Container(
        color: notif.isRead ? Colors.transparent : _C.primary.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(notif.type), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.title,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: _C.textPrimary,
                          )),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _C.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (notif.body != null) ...[
                    const SizedBox(height: 4),
                    Text(notif.body!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 13, color: _C.textSecondary, height: 1.4)),
                  ],
                  const SizedBox(height: 6),
                  Text(_timeAgo(notif.createdAt),
                    style: GoogleFonts.outfit(fontSize: 11, color: _C.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _C.divider),
            ),
            child: const Icon(Icons.notifications_off_rounded, size: 40, color: _C.divider),
          ),
          const SizedBox(height: 20),
          Text('Chưa có thông báo',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: _C.textPrimary)),
          const SizedBox(height: 8),
          Text('Thông báo sẽ xuất hiện ở đây',
            style: GoogleFonts.outfit(fontSize: 14, color: _C.textMuted)),
        ],
      ),
    );
  }
}
